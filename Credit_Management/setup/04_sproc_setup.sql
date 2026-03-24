-- =========================================================
-- ネット銀行 与信管理 × Snowflake AI Agent MVP
--
-- 04_sproc_setup.sql - Stored Procedure（Agent カスタムツール）
-- =========================================================
-- 作成日: 2026/03
-- =========================================================
--
-- ⚠️ 前提条件:
--   - 01_db_setup.sql を先に実行済みであること
--   - ACCOUNTADMIN 権限が必要
--
-- =========================================================

SET DB_NAME    = COALESCE($DB_NAME,    'CREDIT_MGMT_DB');
SET WH_NAME    = COALESCE($WH_NAME,    'CREDIT_MGMT_WH');
SET ADMIN_ROLE = COALESCE($ADMIN_ROLE,  'ACCOUNTADMIN');

USE ROLE IDENTIFIER($ADMIN_ROLE);
USE DATABASE IDENTIFIER($DB_NAME);
USE WAREHOUSE IDENTIFIER($WH_NAME);
USE SCHEMA AGENT;


-- =========================================================
-- 事前準備: Email Integration の作成
-- =========================================================
CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_INTEGRATION
    TYPE = EMAIL
    ENABLED = TRUE;


-- =========================================================
-- Stored Procedure 1: 信用スコア算出
-- =========================================================
-- 【用途】
--   最新の財務指標から信用スコア（0〜100）を算出する。
--   Agent 経由で「A社の信用スコアを計算して」に対応。
--
-- 【スコアリングロジック】（簡易版）
--   自己資本比率      : 30 点満点
--   流動比率          : 20 点満点
--   インタレストカバレッジ : 20 点満点
--   ROA               : 15 点満点
--   延滞有無          : 15 点満点
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE CALCULATE_CREDIT_SCORE("CUSTOMER_NAME_INPUT" VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'calculate_credit_score'
COMMENT = '財務指標から信用スコア（0〜100）を算出。Agent ツールとして利用。'
EXECUTE AS OWNER
AS '
def calculate_credit_score(session, customer_name_input):
    import json

    rows = session.sql(f"""
        SELECT
            c.CUSTOMER_ID,
            c.CUSTOMER_NAME,
            c.CREDIT_RATING,
            c.RISK_SEGMENT,
            fs.FISCAL_YEAR_END,
            fs.EQUITY_RATIO,
            fs.CURRENT_RATIO,
            fs.INTEREST_COVERAGE,
            fs.ROA,
            fs.REVENUE,
            fs.NET_INCOME,
            COALESCE(SUM(CASE WHEN l.LOAN_STATUS = ''延滞'' THEN 1 ELSE 0 END), 0) AS DELINQUENT_COUNT,
            COALESCE(SUM(l.OUTSTANDING_BALANCE), 0) AS TOTAL_LOAN_BALANCE
        FROM CREDIT_DATA.CUSTOMER c
        LEFT JOIN CREDIT_DATA.FINANCIAL_STATEMENT fs
            ON c.CUSTOMER_ID = fs.CUSTOMER_ID
        LEFT JOIN CREDIT_DATA.LOAN l
            ON c.CUSTOMER_ID = l.CUSTOMER_ID AND l.RECORD_DATE = ''2025-01-31''
        WHERE UPPER(c.CUSTOMER_NAME) LIKE UPPER(''%{customer_name_input}%'')
        GROUP BY c.CUSTOMER_ID, c.CUSTOMER_NAME, c.CREDIT_RATING, c.RISK_SEGMENT,
                 fs.FISCAL_YEAR_END, fs.EQUITY_RATIO, fs.CURRENT_RATIO,
                 fs.INTEREST_COVERAGE, fs.ROA, fs.REVENUE, fs.NET_INCOME
        ORDER BY fs.FISCAL_YEAR_END DESC NULLS LAST
        LIMIT 1
    """).collect()

    if not rows:
        return json.dumps({"error": f"企業名「{customer_name_input}」に該当する顧客が見つかりません。"}, ensure_ascii=False)

    r = rows[0]
    score = 0
    details = []

    eq = float(r["EQUITY_RATIO"] or 0)
    if eq >= 50: s = 30
    elif eq >= 30: s = 20
    elif eq >= 15: s = 10
    else: s = 0
    score += s
    details.append(f"自己資本比率 {eq}% → {s}/30点")

    cr = float(r["CURRENT_RATIO"] or 0)
    if cr >= 200: s = 20
    elif cr >= 150: s = 15
    elif cr >= 100: s = 10
    else: s = 0
    score += s
    details.append(f"流動比率 {cr}% → {s}/20点")

    ic = float(r["INTEREST_COVERAGE"] or 0)
    if ic >= 10: s = 20
    elif ic >= 5: s = 15
    elif ic >= 2: s = 10
    elif ic >= 0: s = 5
    else: s = 0
    score += s
    details.append(f"ICR {ic} → {s}/20点")

    roa = float(r["ROA"] or 0)
    if roa >= 5: s = 15
    elif roa >= 3: s = 10
    elif roa >= 0: s = 5
    else: s = 0
    score += s
    details.append(f"ROA {roa}% → {s}/15点")

    delinq = int(r["DELINQUENT_COUNT"])
    if delinq == 0: s = 15
    else: s = 0
    score += s
    details.append(f"延滞件数 {delinq}件 → {s}/15点")

    if score >= 80: grade = "A以上（優良）"
    elif score >= 60: grade = "BBB〜A（標準）"
    elif score >= 40: grade = "BB〜BBB（注意）"
    else: grade = "B以下（要管理）"

    result = {
        "企業名": r["CUSTOMER_NAME"],
        "現在格付": r["CREDIT_RATING"],
        "リスクセグメント": r["RISK_SEGMENT"],
        "算出スコア": score,
        "判定": grade,
        "内訳": details,
        "融資残高_百万円": int(r["TOTAL_LOAN_BALANCE"]),
        "直近決算期": str(r["FISCAL_YEAR_END"]) if r["FISCAL_YEAR_END"] else "N/A"
    }
    return json.dumps(result, ensure_ascii=False, indent=2)
';

-- 動作確認
-- CALL CALCULATE_CREDIT_SCORE('クラウドネクスト');
-- CALL CALCULATE_CREDIT_SCORE('オールドメタル');
-- CALL CALCULATE_CREDIT_SCORE('サニーエステート');


-- =========================================================
-- Stored Procedure 2: 審査レポートドラフト生成
-- =========================================================
-- 【用途】
--   顧客の財務・融資・担保情報を集約し、審査レポートのドラフトを生成。
--   Agent 経由で「A社の審査レポートを作成して」に対応。
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE GENERATE_REVIEW_REPORT("CUSTOMER_NAME_INPUT" VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_review_report'
COMMENT = '顧客の財務・融資・担保情報を集約し、審査レポートのドラフトを生成。'
EXECUTE AS OWNER
AS '
def generate_review_report(session, customer_name_input):
    import json

    cust_rows = session.sql(f"""
        SELECT * FROM CREDIT_DATA.CUSTOMER
        WHERE UPPER(CUSTOMER_NAME) LIKE UPPER(''%{customer_name_input}%'')
        LIMIT 1
    """).collect()

    if not cust_rows:
        return json.dumps({"error": f"企業名「{customer_name_input}」が見つかりません。"}, ensure_ascii=False)

    cust = cust_rows[0]
    cid = cust["CUSTOMER_ID"]

    fs_rows = session.sql(f"""
        SELECT * FROM CREDIT_DATA.FINANCIAL_STATEMENT
        WHERE CUSTOMER_ID = {cid}
        ORDER BY FISCAL_YEAR_END DESC LIMIT 3
    """).collect()

    loan_rows = session.sql(f"""
        SELECT * FROM CREDIT_DATA.LOAN
        WHERE CUSTOMER_ID = {cid} AND RECORD_DATE = ''2025-01-31''
    """).collect()

    col_rows = session.sql(f"""
        SELECT co.* FROM CREDIT_DATA.COLLATERAL co
        JOIN CREDIT_DATA.LOAN l ON co.LOAN_ID = l.LOAN_ID
        WHERE l.CUSTOMER_ID = {cid} AND l.RECORD_DATE = ''2025-01-31''
    """).collect()

    review_rows = session.sql(f"""
        SELECT * FROM CREDIT_DATA.CREDIT_REVIEW
        WHERE CUSTOMER_ID = {cid}
        ORDER BY REVIEW_DATE DESC LIMIT 3
    """).collect()

    report = []
    report.append("=" * 60)
    report.append(f"  与信審査レポート: {cust[''CUSTOMER_NAME'']}")
    report.append("=" * 60)
    report.append("")

    report.append("■ 1. 企業概要")
    report.append(f"  企業名      : {cust[''CUSTOMER_NAME'']}")
    report.append(f"  業種        : {cust[''INDUSTRY_NAME'']} / {cust[''SUB_INDUSTRY''] or ''N/A''}")
    report.append(f"  売上高      : {cust[''ANNUAL_REVENUE'']}百万円")
    report.append(f"  従業員数    : {cust[''EMPLOYEE_COUNT'']}名")
    report.append(f"  現在格付    : {cust[''CREDIT_RATING'']}")
    report.append(f"  リスク区分  : {cust[''RISK_SEGMENT'']}")
    report.append(f"  担当RM      : {cust[''RELATIONSHIP_MANAGER'']}")
    report.append("")

    report.append("■ 2. 財務推移")
    if fs_rows:
        report.append(f"  {'決算期末':<12} {'売上高':<10} {'営業利益':<10} {'純利益':<10} {'自己資本比率':<12} {'流動比率':<10}")
        for fs in reversed(fs_rows):
            report.append(f"  {str(fs[''FISCAL_YEAR_END'']):<12} {fs[''REVENUE''] or 0:<10} {fs[''OPERATING_PROFIT''] or 0:<10} {fs[''NET_INCOME''] or 0:<10} {fs[''EQUITY_RATIO''] or 0:<12} {fs[''CURRENT_RATIO''] or 0:<10}")
    else:
        report.append("  財務データなし")
    report.append("")

    report.append("■ 3. 融資状況")
    total_balance = 0
    for l in loan_rows:
        total_balance += int(l["OUTSTANDING_BALANCE"] or 0)
        status_mark = "⚠️" if l["LOAN_STATUS"] in ("延滞", "条件変更") else "✓"
        report.append(f"  {status_mark} ID:{l[''LOAN_ID'']} | {l[''LOAN_PURPOSE''] or l[''LOAN_TYPE'']} | 残高:{l[''OUTSTANDING_BALANCE'']}百万円 | 金利:{l[''INTEREST_RATE'']}% | {l[''LOAN_STATUS'']}")
        if int(l["DAYS_PAST_DUE"] or 0) > 0:
            report.append(f"     → 延滞日数: {l[''DAYS_PAST_DUE'']}日")
    report.append(f"  ────────────────────────────")
    report.append(f"  融資残高合計: {total_balance}百万円")
    report.append("")

    report.append("■ 4. 担保状況")
    total_secured = 0
    if col_rows:
        for co in col_rows:
            total_secured += int(co["SECURED_VALUE"] or 0)
            report.append(f"  {co[''COLLATERAL_TYPE'']} | 評価額:{co[''APPRAISED_VALUE'']}百万円 | 掛目:{co[''HAIRCUT_RATE'']}% | 担保価値:{co[''SECURED_VALUE'']}百万円")
        cover_rate = round(total_secured / total_balance * 100, 1) if total_balance > 0 else 0
        report.append(f"  担保カバー率: {cover_rate}%")
    else:
        report.append("  担保なし（無担保融資）")
    report.append("")

    report.append("■ 5. 過去の審査履歴")
    if review_rows:
        for rv in review_rows:
            report.append(f"  {rv[''REVIEW_DATE'']} | {rv[''REVIEW_TYPE'']} | {rv[''DECISION'']} | {rv[''PREVIOUS_RATING''] or ''N/A''} → {rv[''NEW_RATING''] or ''N/A''}")
            if rv["RISK_FACTORS"]:
                report.append(f"    リスク: {rv[''RISK_FACTORS'']}")
    else:
        report.append("  過去の審査記録なし")
    report.append("")

    report.append("■ 6. 総合所見（ドラフト）")
    warnings = []
    if any(l["LOAN_STATUS"] in ("延滞", "条件変更") for l in loan_rows):
        warnings.append("延滞または条件変更が発生中")
    if fs_rows and float(fs_rows[0]["EQUITY_RATIO"] or 0) < 20:
        warnings.append(f"自己資本比率が低水準（{fs_rows[0][''EQUITY_RATIO'']}%）")
    if fs_rows and float(fs_rows[0]["NET_INCOME"] or 0) < 0:
        warnings.append("直近決算で当期純損失を計上")
    if total_balance > 0 and total_secured / total_balance < 0.5:
        warnings.append(f"担保カバー率が50%未満（{round(total_secured/total_balance*100,1) if total_balance else 0}%）")

    if warnings:
        report.append("  【注意事項】")
        for w in warnings:
            report.append(f"  ⚠️ {w}")
    else:
        report.append("  特段の懸念事項なし。与信維持が妥当と判断。")

    report.append("")
    report.append("=" * 60)
    report.append("  本レポートは AI が自動生成したドラフトです。")
    report.append("  最終判断は審査担当者が行ってください。")
    report.append("=" * 60)

    return "\\n".join(report)
';

-- 動作確認
-- CALL GENERATE_REVIEW_REPORT('精密機器製作所');
-- CALL GENERATE_REVIEW_REPORT('オールドメタル');
-- CALL GENERATE_REVIEW_REPORT('サニーエステート');


-- =========================================================
-- Stored Procedure 3: メール送信
-- =========================================================

CREATE OR REPLACE PROCEDURE SEND_EMAIL(
    "RECIPIENT_EMAIL" VARCHAR,
    "SUBJECT" VARCHAR,
    "BODY" VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
COMMENT = 'Agent から分析結果・レポートをメール送信するプロシージャ'
EXECUTE AS OWNER
AS '
def send_email(session, recipient_email, subject, body):
    try:
        escaped_body = body.replace("''", "''''")
        escaped_subject = subject.replace("''", "''''")
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                ''EMAIL_INTEGRATION'',
                ''{recipient_email}'',
                ''{escaped_subject}'',
                ''{escaped_body}'',
                ''text/html''
            )
        """).collect()
        return "メールを送信しました: " + recipient_email
    except Exception as e:
        return f"メール送信エラー: {str(e)}"
';


-- =========================================================
-- Stored Procedure 4: ドキュメントダウンロード URL 生成
-- =========================================================

CREATE OR REPLACE PROCEDURE GET_DOCUMENT_DOWNLOAD_URL(
    relative_file_path STRING,
    expiration_mins INTEGER DEFAULT 5
)
RETURNS STRING
LANGUAGE SQL
COMMENT = '与信規程PDF等のダウンロード用署名付きURLを生成'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
    stage_name STRING DEFAULT '@DOCUMENTS.credit_docs';
    file_count INTEGER;
    available_files STRING;
BEGIN
    expiration_seconds := expiration_mins * 60;

    EXECUTE IMMEDIATE 'LIST ' || stage_name;

    SELECT COUNT(*)
    INTO :file_count
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "name" LIKE '%' || :relative_file_path
       OR "name" LIKE '%/' || :relative_file_path;

    IF (file_count = 0) THEN
        EXECUTE IMMEDIATE 'LIST ' || stage_name;
        SELECT LISTAGG(SPLIT_PART("name", '/', -1), ', ') WITHIN GROUP (ORDER BY "name")
        INTO :available_files
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE "name" LIKE '%.pdf' OR "name" LIKE '%.PDF';

        IF (available_files IS NULL OR available_files = '') THEN
            RETURN 'エラー: ステージにPDFファイルが存在しません。先にアップロードしてください。';
        ELSE
            RETURN 'エラー: 「' || relative_file_path || '」が見つかりません。利用可能: ' || available_files;
        END IF;
    END IF;

    sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ''' || relative_file_path || ''', ' || expiration_seconds || ') AS url';
    EXECUTE IMMEDIATE :sql_stmt;

    SELECT "URL"
    INTO :presigned_url
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    RETURN presigned_url;
END;
$$;


-- =========================================================
-- 権限設定（必要に応じてアプリケーション用ロールに付与）
-- =========================================================
-- GRANT USAGE ON PROCEDURE CALCULATE_CREDIT_SCORE(VARCHAR) TO ROLE <APP_ROLE>;
-- GRANT USAGE ON PROCEDURE GENERATE_REVIEW_REPORT(VARCHAR) TO ROLE <APP_ROLE>;
-- GRANT USAGE ON PROCEDURE SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR) TO ROLE <APP_ROLE>;


-- =========================================================
-- 04_sproc_setup.sql 完了
-- =========================================================
--
-- 作成されたオブジェクト:
--
-- [CREDIT_MGMT_DB.AGENT]
--   - CALCULATE_CREDIT_SCORE（信用スコア算出）
--   - GENERATE_REVIEW_REPORT（審査レポートドラフト生成）
--   - SEND_EMAIL（メール送信）
--   - GET_DOCUMENT_DOWNLOAD_URL（PDF ダウンロード URL 生成）
--   - EMAIL_INTEGRATION（通知インテグレーション）
--
-- 次のステップ:
--   → 05_agent_setup.sql（Agent 作成 & Intelligence 公開）
--
-- =========================================================
