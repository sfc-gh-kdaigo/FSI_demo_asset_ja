-- =========================================================
-- ネット銀行 与信管理 × Snowflake AI Agent MVP
--
-- 05_agent_setup.sql - Cortex Agent 作成 & Intelligence 公開
-- =========================================================
-- 作成日: 2026/03
-- =========================================================
--
-- ⚠️ 前提条件:
--   - 01_db_setup.sql 〜 04_sproc_setup.sql を実行済み
--   - 03_sv_setup.sql で Semantic View を作成済み
--   - CROSS_REGION 推論が有効（01 で設定済み）
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
-- Step 1: Cortex Agent の作成
-- =========================================================

-- =========================================================
-- =========================================================

CREATE OR REPLACE AGENT CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT
  COMMENT = 'ネット銀行の与信管理業務を支援するAIエージェント'
  FROM SPECIFICATION $$
  {
    "models": {
      "orchestration": "claude-3-5-sonnet"
    },
    "instructions": {
      "orchestration": "ユーザーの質問に応じて適切なツールを選択してください。融資残高・財務指標・業種別分析などのデータ分析にはcredit_analysis_svを使用。面談・審査記録の検索にはcredit_review_searchを使用。与信規程・業界レポートの照会にはcredit_policy_searchを使用。信用スコア算出にはcalculate_credit_score、審査レポート生成にはgenerate_review_reportを使用。",
      "response": "全ての回答は日本語で行うこと。数値データには必ず単位（百万円、%等）と基準日を明記。結論を最初に述べ、詳細データは表形式で提示。リスク要因や注意事項があれば必ず明示。",
      "sample_questions": [
        {
          "question": "業種別の融資残高と件数を教えてください",
          "answer": "credit_analysis_svを使って業種別のポートフォリオ分析を実行します。"
        },
        {
          "question": "延滞が発生している融資先の状況を教えてください",
          "answer": "credit_analysis_svで延滞先の一覧と延滞日数を取得します。"
        },
        {
          "question": "オールドメタルの信用スコアを計算してください",
          "answer": "calculate_credit_scoreで財務指標に基づく信用スコアを算出します。"
        },
        {
          "question": "サニーエステートの審査レポートを作成してください",
          "answer": "generate_review_reportで財務・融資・担保情報を集約したレポートを生成します。"
        },
        {
          "question": "クラウドネクストとの直近の面談内容を教えてください",
          "answer": "credit_review_searchで面談記録を検索します。"
        },
        {
          "question": "要注意先への追加融資の基準は？",
          "answer": "credit_policy_searchで与信規程ガイドラインの該当箇所を検索します。"
        },
        {
          "question": "オールドメタルの財務推移と過去の審査で指摘されたリスクをまとめてください",
          "answer": "credit_analysis_svで財務データを取得し、credit_review_searchで審査記録を検索して総合分析します。"
        },
        {
          "question": "不動産担保の掛目基準は？",
          "answer": "credit_policy_searchで与信規程の担保掛目基準を検索します。"
        }
      ]
    },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "credit_analysis_sv",
          "description": "融資残高、延滞状況、財務指標、業種別ポートフォリオ、担保カバー率など、与信管理に関するデータ分析クエリを自然言語からSQLに変換して実行します。"
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "credit_review_search",
          "description": "過去の審査レポートや面談議事録を検索します。特定企業の審査論点、面談経緯、リスク指摘事項を調べる際に使用。"
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "credit_policy_search",
          "description": "与信規程ガイドライン、業界動向レポートなどの社内文書を検索します。融資基準、担保掛目、決裁権限、業界別リスクなどを調べる際に使用。"
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "calculate_credit_score",
          "description": "企業名を指定して財務指標に基づく信用スコア（0〜100点）を算出します。自己資本比率、流動比率、ICR、ROA、延滞状況を評価。",
          "input_schema": {
            "type": "object",
            "properties": {
              "CUSTOMER_NAME_INPUT": {
                "type": "string",
                "description": "信用スコアを算出する企業名（部分一致可）"
              }
            },
            "required": ["CUSTOMER_NAME_INPUT"]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "generate_review_report",
          "description": "企業名を指定して、財務・融資・担保・審査履歴を集約した与信審査レポートのドラフトを自動生成します。",
          "input_schema": {
            "type": "object",
            "properties": {
              "CUSTOMER_NAME_INPUT": {
                "type": "string",
                "description": "審査レポートを生成する企業名（部分一致可）"
              }
            },
            "required": ["CUSTOMER_NAME_INPUT"]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "send_email",
          "description": "分析結果やレポートをメールで送信します。",
          "input_schema": {
            "type": "object",
            "properties": {
              "RECIPIENT_EMAIL": {
                "type": "string",
                "description": "送信先メールアドレス"
              },
              "SUBJECT": {
                "type": "string",
                "description": "メール件名"
              },
              "BODY": {
                "type": "string",
                "description": "メール本文（HTML対応）"
              }
            },
            "required": ["RECIPIENT_EMAIL", "SUBJECT", "BODY"]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "get_document_download_url",
          "description": "与信規程PDFなどのダウンロード用署名付きURLを生成します。",
          "input_schema": {
            "type": "object",
            "properties": {
              "RELATIVE_FILE_PATH": {
                "type": "string",
                "description": "ステージ内のファイルパス"
              },
              "EXPIRATION_MINS": {
                "type": "integer",
                "description": "URL有効期限（分）。デフォルト5分。"
              }
            },
            "required": ["RELATIVE_FILE_PATH"]
          }
        }
      }
    ],
    "tool_resources": {
      "credit_analysis_sv": {
        "semantic_view": "CREDIT_MGMT_DB.ANALYTICS.CREDIT_ANALYSIS_SV"
      },
      "credit_review_search": {
        "search_service": "CREDIT_MGMT_DB.DOCUMENTS.CREDIT_REVIEW_SEARCH",
        "max_results": 10
      },
      "credit_policy_search": {
        "search_service": "CREDIT_MGMT_DB.DOCUMENTS.CREDIT_POLICY_SEARCH",
        "max_results": 5
      },
      "calculate_credit_score": {
        "type": "procedure",
        "identifier": "CREDIT_MGMT_DB.AGENT.CALCULATE_CREDIT_SCORE",
        "execution_environment": {
          "type": "warehouse",
          "name": "CREDIT_MGMT_WH"
        }
      },
      "generate_review_report": {
        "type": "procedure",
        "identifier": "CREDIT_MGMT_DB.AGENT.GENERATE_REVIEW_REPORT",
        "execution_environment": {
          "type": "warehouse",
          "name": "CREDIT_MGMT_WH"
        }
      },
      "send_email": {
        "type": "procedure",
        "identifier": "CREDIT_MGMT_DB.AGENT.SEND_EMAIL",
        "execution_environment": {
          "type": "warehouse",
          "name": "CREDIT_MGMT_WH"
        }
      },
      "get_document_download_url": {
        "type": "procedure",
        "identifier": "CREDIT_MGMT_DB.AGENT.GET_DOCUMENT_DOWNLOAD_URL",
        "execution_environment": {
          "type": "warehouse",
          "name": "CREDIT_MGMT_WH"
        }
      }
    }
  }
  $$;


-- =========================================================
-- Step 2: 動作確認（テストクエリ）
-- =========================================================
-- 以下のクエリで Agent の動作を確認できます

-- 基本動作テスト（Analyst）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   '融資残高が大きい企業トップ5を教えてください'
-- );

-- 延滞分析（Analyst）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   '延滞が発生している融資先の一覧と延滞日数を教えてください'
-- );

-- 面談記録検索（Search）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   'オールドメタルとの直近の面談で話した内容を教えてください'
-- );

-- 信用スコア算出（Sproc）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   'オールドメタルの信用スコアを計算してください'
-- );

-- 審査レポート生成（Sproc）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   'サニーエステートの審査レポートを作成してください'
-- );

-- 複合質問（Analyst + Search）
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--   'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
--   'オールドメタルの財務状況の推移と、過去の審査で指摘されたリスクをまとめてください'
-- );


-- =========================================================
-- Step 3: Snowflake CoWork への公開
-- =========================================================
-- Snowflake CoWork は GUI で設定します。
--
-- 【手順】
-- 1. Snowsight > AI & ML > Snowflake CoWork を開く
-- 2. 「+ Intelligence」ボタンをクリック
-- 3. 以下の情報を入力:
--
--    名前: 与信管理AI
--    説明: ネット銀行の与信管理業務を支援するAIエージェントです。
--          融資・財務分析、延滞管理、審査レポート生成などに対応します。
--
-- 4. Agent を選択:
--    CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT
--
-- 5. サンプル質問を登録（以下をコピー）:
--    - 融資残高が大きい企業トップ10を教えてください
--    - 延滞が発生している融資先の状況を教えてください
--    - オールドメタルの信用スコアを計算してください
--    - サニーエステートの審査レポートを作成してください
--    - 業種別の融資ポートフォリオを分析してください
--    - クラウドネクストとの直近の面談内容を教えてください
--
-- 6. 「公開」をクリック
--
-- 【アクセス権限の設定】
-- Intelligence を他ユーザーに公開する場合は、
-- 対象ロールに以下の権限を付与してください:
--
-- GRANT USAGE ON DATABASE CREDIT_MGMT_DB TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA CREDIT_MGMT_DB.AGENT TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA CREDIT_MGMT_DB.ANALYTICS TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA CREDIT_MGMT_DB.CREDIT_DATA TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA CREDIT_MGMT_DB.DOCUMENTS TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON WAREHOUSE CREDIT_MGMT_WH TO ROLE <TARGET_ROLE>;


-- =========================================================
-- Step 4: デモシナリオ
-- =========================================================
--
-- ┌────────────────────────────────────────────────────────────────┐
-- │  デモシナリオ一覧                                               │
-- ├────┬──────────────┬─────────────────────────────────────────┤
-- │ #  │ シナリオ       │ 質問例                                    │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 1  │ ポートフォリオ │ 業種別の融資残高と件数を教えて              │
-- │    │ 全体像        │ → Analyst                                 │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 2  │ 延滞管理      │ 延滞先の一覧と各社の状況を教えて            │
-- │    │              │ → Analyst                                 │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 3  │ 信用分析      │ オールドメタルの信用スコアを計算して          │
-- │    │              │ → Sproc (CALCULATE_CREDIT_SCORE)         │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 4  │ 財務悪化検知  │ 直近決算で営業赤字の企業は？                │
-- │    │              │ → Analyst                                 │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 5  │ 面談記録照会  │ サニーエステートとの面談で何を話した？        │
-- │    │              │ → Search (CREDIT_REVIEW_SEARCH)          │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 6  │ 審査レポート  │ オールドメタルの審査レポートを作成して        │
-- │    │              │ → Sproc (GENERATE_REVIEW_REPORT)         │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 7  │ 複合分析      │ オールドメタルの財務推移と過去の審査論点を    │
-- │    │              │ まとめて、今後の対応方針を提案して           │
-- │    │              │ → Analyst + Search + Sproc               │
-- ├────┼──────────────┼─────────────────────────────────────────┤
-- │ 8  │ 規程照会      │ 要注意先への追加融資の基準は？              │
-- │    │              │ → Search (CREDIT_POLICY_SEARCH)          │
-- └────┴──────────────┴─────────────────────────────────────────┘
--
-- デモのストーリーライン（推奨順序）:
--   1 → 2 → 4 → 3 → 5 → 7 → 6
--   「全体把握 → 問題発見 → 深掘り → 対応」の流れ


-- =========================================================
-- 05_agent_setup.sql 完了
-- =========================================================
--
-- 作成されたオブジェクト:
--
-- [CREDIT_MGMT_DB.AGENT]
--   - CREDIT_MANAGEMENT_AGENT（Cortex Agent）
--
-- Agent ツール構成:
--   1. CREDIT_ANALYSIS_SV      (Semantic View)
--   2. CREDIT_REVIEW_SEARCH    (Cortex Search)
--   3. CREDIT_POLICY_SEARCH    (Cortex Search)
--   4. CALCULATE_CREDIT_SCORE  (Stored Procedure)
--   5. GENERATE_REVIEW_REPORT  (Stored Procedure)
--   6. SEND_EMAIL              (Stored Procedure)
--   7. GET_DOCUMENT_DOWNLOAD_URL (Stored Procedure)
--
-- 全 Phase 完了。ファイル一覧:
--   01_db_setup.sql       → 環境構築・テーブル・サンプルデータ
--   02_search_setup.sql   → Cortex Search 設定
--   03_sv_setup.sql       → Semantic View 作成
--   04_sproc_setup.sql    → Stored Procedure
--   05_agent_setup.sql    → Agent 作成 & Intelligence 公開
--
-- =========================================================
