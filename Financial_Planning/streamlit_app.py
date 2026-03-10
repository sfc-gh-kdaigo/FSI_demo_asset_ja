import streamlit as st
import json
from typing import Optional
import _snowflake
from snowflake.snowpark.context import get_active_session

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------

API_ENDPOINT = "/api/v2/cortex/agent:run"
API_TIMEOUT = 60000

DATABASE = "BANK_BPR_DB"
SCHEMA = "ANALYTICS"

SV_FINANCIAL = f"{DATABASE}.{SCHEMA}.SV_FINANCIAL_ACCOUNTING"
SV_MANAGEMENT = f"{DATABASE}.{SCHEMA}.SV_MANAGEMENT_ACCOUNTING"
REGULATION_SEARCH = f"{DATABASE}.{SCHEMA}.REGULATION_SEARCH_SERVICE"
REPORTS_SEARCH = f"{DATABASE}.{SCHEMA}.FINANCIAL_REPORTS_SEARCH_SERVICE"

AGENT_MODEL = "claude-4-sonnet"

RESPONSE_INSTRUCTION = (
    "あなたは大手信託銀行の財務企画部を支援する専門AIアシスタントです。"
    "予算管理、収益分析、決算業務、行内規程の照会を行います。\n\n"
    "回答ガイドライン:\n"
    "- すべて日本語で回答すること\n"
    "- 数値データには必ず前期比・予算比のコメントを付与すること\n"
    "- 規程に基づく判断には出典（規程名・条項番号）を明記すること\n"
    "- 金額は百万円単位で統一し、変動率は%で表記すること\n"
    "- 回答の冒頭に1-2文の要約を記載すること\n"
    "- 回答は簡潔かつ包括的であること"
)

ORCHESTRATION_INSTRUCTION = (
    "クエリの分解と分類:\n"
    "- 財務会計データ（仕訳・GL・予算）は financial_accounting ツールを使用\n"
    "- 管理会計データ（事業PL・TP・財管差）は management_accounting ツールを使用\n"
    "- 規程・通達の照会は regulation_search ツールを使用\n"
    "- 過去の決算資料の参照は financial_reports_search ツールを使用\n"
    "- 複合的な質問は逐次的に各ツールを呼び出し、結果を統合して回答する"
)

SAMPLE_QUESTIONS = [
    "今四半期の営業経費の予算消化率を部門別に表示してください",
    "リテール事業と市場事業の今期PLを比較してください",
    "財管差が大きいセグメントと主要勘定を教えてください",
    "社内仕切りの影響額をセグメント別に見せてください",
    "今期の決算補正仕訳の一覧を金額降順で表示してください",
    "前年同期比で有価証券利息の推移を月次で見せてください",
]

session = get_active_session()


# ---------------------------------------------------------------------------
# API 呼び出し
# ---------------------------------------------------------------------------

def call_agent_api(query: str, message_history: list) -> Optional[dict]:
    """Cortex Agent API を呼び出す"""
    messages = []
    for msg in message_history:
        messages.append({
            "role": msg["role"],
            "content": [{"type": "text", "text": msg["content"]}],
        })
    messages.append({
        "role": "user",
        "content": [{"type": "text", "text": query}],
    })

    payload = {
        "model": AGENT_MODEL,
        "messages": messages,
        "tools": [
            {
                "tool_spec": {
                    "type": "cortex_analyst_text_to_sql",
                    "name": "financial_accounting",
                    "description": "財務会計データ（仕訳明細・GL残高・予算）を分析。予算消化率、決算補正仕訳一覧、勘定別推移などのクエリに対応。",
                }
            },
            {
                "tool_spec": {
                    "type": "cortex_analyst_text_to_sql",
                    "name": "management_accounting",
                    "description": "管理会計データ（事業別損益・社内仕切り・財管差）を分析。セグメント別PL比較、TP影響額計算、財管差要因分析に対応。",
                }
            },
            {
                "tool_spec": {
                    "type": "cortex_search",
                    "name": "regulation_search",
                    "description": "行内規定集、会計処理通達、経費精算ガイドラインのPDFを検索。経費処理の妥当性判断や会計ルールの確認に使用。",
                }
            },
            {
                "tool_spec": {
                    "type": "cortex_search",
                    "name": "financial_reports_search",
                    "description": "過去の決算資料、報告書テンプレート、当局提出書類のPDFを検索。過去の開示内容の確認や報告書ドラフト作成支援に使用。",
                }
            },
        ],
        "tool_resources": {
            "financial_accounting": {
                "semantic_view": SV_FINANCIAL,
                "execution_environment": {
                    "type": "warehouse",
                    "warehouse": "BANK_BPR_WH",
                },
            },
            "management_accounting": {
                "semantic_view": SV_MANAGEMENT,
                "execution_environment": {
                    "type": "warehouse",
                    "warehouse": "BANK_BPR_WH",
                },
            },
            "regulation_search": {
                "search_service": REGULATION_SEARCH,
                "max_results": 5,
                "title_column": "DOC_TITLE",
                "id_column": "CHUNK_INDEX",
            },
            "financial_reports_search": {
                "search_service": REPORTS_SEARCH,
                "max_results": 5,
                "title_column": "DOC_TITLE",
                "id_column": "CHUNK_INDEX",
            },
        },
        "response_instruction": RESPONSE_INSTRUCTION,
        "orchestration_instruction": ORCHESTRATION_INSTRUCTION,
    }

    try:
        resp = _snowflake.send_snow_api_request(
            "POST",
            API_ENDPOINT,
            {},
            {"stream": True},
            payload,
            None,
            API_TIMEOUT,
        )

        if resp["status"] != 200:
            st.error(f"API エラー: {resp['status']}")
            return None

        return json.loads(resp["content"])

    except Exception as e:
        st.error(f"リクエストエラー: {str(e)}")
        return None


# ---------------------------------------------------------------------------
# SSE レスポンス処理
# ---------------------------------------------------------------------------

def process_sse_response(response) -> tuple:
    """SSE レスポンスからテキスト・SQL・引用・使用ツールを抽出"""
    text = ""
    sql = ""
    citations = []
    tools_used = []

    if not response:
        return text, sql, citations, tools_used

    try:
        for event in response:
            if event.get("event") == "message.delta":
                data = event.get("data", {})
                delta = data.get("delta", {})

                for item in delta.get("content", []):
                    content_type = item.get("type")

                    if content_type == "tool_results":
                        tool_results = item.get("tool_results", {})
                        tool_name = tool_results.get("name", "")
                        if tool_name and tool_name not in tools_used:
                            tools_used.append(tool_name)

                        for result in tool_results.get("content", []):
                            if result.get("type") == "json":
                                json_data = result.get("json", {})
                                text += json_data.get("text", "")
                                sql = json_data.get("sql", "") or sql

                                for sr in json_data.get("searchResults", []):
                                    citations.append({
                                        "source_id": sr.get("source_id", ""),
                                        "doc_title": sr.get("doc_title", ""),
                                        "doc_chunk": sr.get("doc_id", ""),
                                    })

                    elif content_type == "text":
                        text += item.get("text", "")

    except Exception as e:
        st.error(f"レスポンス処理エラー: {str(e)}")

    return text, sql, citations, tools_used


def run_query(sql_text: str):
    """SQL を実行して結果を返す"""
    try:
        return session.sql(sql_text.replace(";", ""))
    except Exception as e:
        st.error(f"SQL 実行エラー: {str(e)}")
        return None


# ---------------------------------------------------------------------------
# ツール名の表示マッピング（英語 → 日本語）
# ---------------------------------------------------------------------------

TOOL_DISPLAY_NAMES = {
    "financial_accounting": "財務会計分析",
    "management_accounting": "管理会計分析",
    "regulation_search": "規程検索",
    "financial_reports_search": "決算資料検索",
}


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

def render_sidebar():
    """サイドバーを描画"""
    with st.sidebar:
        st.markdown("### ❄ Snowflake")
        st.markdown("---")

        if st.button("新規会話", use_container_width=True, type="primary"):
            st.session_state.messages = []
            st.rerun()

        st.markdown("### クイックアクション")

        st.markdown("**財務会計**")
        quick_fa = [
            ("予算消化率分析", SAMPLE_QUESTIONS[0]),
            ("決算補正仕訳一覧", SAMPLE_QUESTIONS[4]),
            ("有価証券利息推移", SAMPLE_QUESTIONS[5]),
        ]
        for label, q in quick_fa:
            if st.button(f"📊 {label}", key=f"qa_{label}", use_container_width=True):
                st.session_state.pending_query = q
                st.rerun()

        st.markdown("**管理会計**")
        quick_ma = [
            ("事業別PL比較", SAMPLE_QUESTIONS[1]),
            ("財管差分析", SAMPLE_QUESTIONS[2]),
            ("社内仕切り影響", SAMPLE_QUESTIONS[3]),
        ]
        for label, q in quick_ma:
            if st.button(f"📈 {label}", key=f"qa_{label}", use_container_width=True):
                st.session_state.pending_query = q
                st.rerun()


def render_assistant_message(text: str, sql: str, citations: list, tools_used: list):
    """アシスタントメッセージを描画"""
    cleaned = text.replace("【†", "[").replace("†】", "]")
    st.markdown(cleaned)

    if tools_used:
        with st.expander("使用ツール"):
            for t in tools_used:
                display = TOOL_DISPLAY_NAMES.get(t, t)
                st.markdown(f"- {display}")

    if sql:
        with st.expander("生成 SQL を表示"):
            st.code(sql, language="sql")

        result = run_query(sql)
        if result is not None:
            df = result.to_pandas()
            if not df.empty:
                with st.expander("データテーブルを表示", expanded=True):
                    st.dataframe(df, use_container_width=True)

    if citations:
        with st.expander("参照ドキュメント"):
            for c in citations:
                src = c.get("source_id", "")
                title = c.get("doc_title", "")
                st.markdown(f"**[{src}]** {title}")


def main():
    st.set_page_config(layout="wide")

    st.title("🏦 財務 AI アシスタント")
    st.caption("財務データ分析・管理会計確認・規程照会をお手伝いします")

    render_sidebar()

    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "pending_query" not in st.session_state:
        st.session_state.pending_query = None

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            if msg["role"] == "assistant":
                render_assistant_message(
                    msg["content"],
                    msg.get("sql", ""),
                    msg.get("citations", []),
                    msg.get("tools_used", []),
                )
            else:
                st.markdown(msg["content"])

    query = st.session_state.pending_query or st.chat_input("メッセージを入力...")
    st.session_state.pending_query = None

    if query:
        with st.chat_message("user"):
            st.markdown(query)
        st.session_state.messages.append({"role": "user", "content": query})

        with st.chat_message("assistant"):
            with st.spinner("分析中..."):
                history = [
                    {"role": m["role"], "content": m["content"]}
                    for m in st.session_state.messages[:-1]
                ]
                response = call_agent_api(query, history)
                text, sql, citations, tools_used = process_sse_response(response)

            if text:
                render_assistant_message(text, sql, citations, tools_used)
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": text,
                    "sql": sql,
                    "citations": citations,
                    "tools_used": tools_used,
                })
            else:
                st.warning("応答を取得できませんでした。もう一度お試しください。")


if __name__ == "__main__":
    main()
