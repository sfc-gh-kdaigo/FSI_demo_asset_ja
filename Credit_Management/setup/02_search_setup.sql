-- =========================================================
-- ネット銀行 与信管理 × Snowflake AI Agent MVP
--
-- 02_search_setup.sql - Cortex Search 設定（RAG 用）
-- =========================================================
-- 作成日: 2026/03
-- =========================================================
--
-- ⚠️ 前提条件:
--   - 01_db_setup.sql を先に実行してデータを作成済みであること
--   - pdf/ ディレクトリにサンプル PDF が格納されていること
--     (credit_policy_guideline.pdf, industry_report_2024.pdf)
--
-- =========================================================

SET DB_NAME    = COALESCE($DB_NAME,    'CREDIT_MGMT_DB');
SET WH_NAME    = COALESCE($WH_NAME,    'CREDIT_MGMT_WH');
SET ADMIN_ROLE = COALESCE($ADMIN_ROLE,  'ACCOUNTADMIN');

USE ROLE IDENTIFIER($ADMIN_ROLE);
USE DATABASE IDENTIFIER($DB_NAME);
USE WAREHOUSE IDENTIFIER($WH_NAME);
USE SCHEMA DOCUMENTS;


-- =========================================================
-- Step 1: PDF ファイルのアップロード
-- =========================================================
-- pdf/ ディレクトリの PDF をステージにアップロード
-- ※ Snowsight のワークシートからは PUT 実行不可のため、
--   SnowSQL または snow CLI で実行してください:
--
--   cd credit-mvp/setup
--   snowsql -q "PUT file://pdf/credit_policy_guideline.pdf @CREDIT_MGMT_DB.DOCUMENTS.credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
--   snowsql -q "PUT file://pdf/industry_report_2024.pdf @CREDIT_MGMT_DB.DOCUMENTS.credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
--   snowsql -q "ALTER STAGE CREDIT_MGMT_DB.DOCUMENTS.credit_docs REFRESH;"

PUT file://pdf/credit_policy_guideline.pdf @credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://pdf/industry_report_2024.pdf @credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

ALTER STAGE credit_docs REFRESH;


-- =========================================================
-- Step 2: PDF パース & チャンク化
-- =========================================================

CREATE OR REPLACE TABLE PARSED_DOCUMENTS_RAW AS
SELECT
    relative_path                   AS FILE_NAME,
    file_url                        AS FILE_URL,
    AI_PARSE_DOCUMENT(
        TO_FILE('@credit_docs', relative_path),
        {'mode': 'LAYOUT', 'page_split': true}
    )                               AS PARSED_CONTENT
FROM DIRECTORY(@credit_docs)
WHERE relative_path LIKE '%.pdf';

CREATE OR REPLACE TABLE DOCUMENT_CHUNKS AS
SELECT
    FILE_NAME,
    FILE_URL,
    f.index                         AS PAGE_NUMBER,
    ROW_NUMBER() OVER (
        ORDER BY FILE_NAME, f.index, c.index
    )                               AS CHUNK_ID,
    c.value::TEXT                    AS CHUNK_TEXT
FROM PARSED_DOCUMENTS_RAW r,
    LATERAL FLATTEN(INPUT => r.PARSED_CONTENT:pages) f,
    LATERAL FLATTEN(INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        f.value:content::TEXT,
        'markdown',
        512,
        128
    )) c;


-- =========================================================
-- Step 3: Cortex Search Service — 審査レポート・面談記録
-- =========================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE CREDIT_REVIEW_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES CUSTOMER_NAME, DOC_TYPE, DOC_DATE
  WAREHOUSE = CREDIT_MGMT_WH
  TARGET_LAG = '1 hour'
AS (
    SELECT
        NOTE_ID                     AS DOC_ID,
        CUSTOMER_NAME,
        'MEETING_NOTE'              AS DOC_TYPE,
        MEETING_DATE                AS DOC_DATE,
        MEETING_CONTENT             AS SEARCH_TEXT,
        KEYWORDS
    FROM MEETING_NOTE

    UNION ALL

    SELECT
        r.REVIEW_ID                 AS DOC_ID,
        c.CUSTOMER_NAME,
        'CREDIT_REVIEW'             AS DOC_TYPE,
        r.REVIEW_DATE               AS DOC_DATE,
        CONCAT(
            '【審査種別】', r.REVIEW_TYPE, '\n',
            '【審査結果】', r.DECISION, '\n',
            '【前格付】', COALESCE(r.PREVIOUS_RATING, 'N/A'),
            ' → 【新格付】', COALESCE(r.NEW_RATING, 'N/A'), '\n',
            '【審査コメント】', COALESCE(r.REVIEW_COMMENT, ''), '\n',
            '【リスク要因】', COALESCE(r.RISK_FACTORS, ''), '\n',
            '【条件事項】', COALESCE(r.CONDITIONS, '')
        )                           AS SEARCH_TEXT,
        NULL                        AS KEYWORDS
    FROM CREDIT_DATA.CREDIT_REVIEW r
    JOIN CREDIT_DATA.CUSTOMER c ON r.CUSTOMER_ID = c.CUSTOMER_ID
);


-- =========================================================
-- Step 4: Cortex Search Service — 与信ポリシー PDF
-- =========================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE CREDIT_POLICY_SEARCH
  ON CHUNK_TEXT
  ATTRIBUTES FILE_NAME, FILE_URL, PAGE_NUMBER
  WAREHOUSE = CREDIT_MGMT_WH
  TARGET_LAG = '1 day'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
    SELECT
        CHUNK_ID,
        FILE_NAME,
        FILE_URL,
        PAGE_NUMBER,
        CHUNK_TEXT
    FROM DOCUMENT_CHUNKS
);


-- =========================================================
-- 動作確認
-- =========================================================
-- CREDIT_REVIEW_SEARCH:
--   「オールドメタルの審査で指摘されたリスクは？」
--
-- CREDIT_POLICY_SEARCH:
--   「不動産担保の掛目基準は？」
--   「要注意先への融資判断基準は？」


-- =========================================================
-- 02_search_setup.sql 完了
-- =========================================================
--
-- 作成されたオブジェクト:
--
-- [CREDIT_MGMT_DB.DOCUMENTS]
--   - PARSED_DOCUMENTS_RAW（PDF パース結果）
--   - DOCUMENT_CHUNKS（チャンク化テキスト）
--   - CREDIT_REVIEW_SEARCH（Cortex Search: 審査・面談記録）
--   - CREDIT_POLICY_SEARCH（Cortex Search: 与信規程 PDF）
--
-- 次のステップ:
--   → 03_sv_setup.sql（Semantic View 作成）
--
-- =========================================================
