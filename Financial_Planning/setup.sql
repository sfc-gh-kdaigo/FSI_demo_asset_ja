-- =====================================================
-- 大手信託銀行 財務企画部 BPR プロジェクト
-- Snowflake Agentic AI - 環境セットアップ
--
-- 実行手順:
--   1. ACCOUNTADMIN ロールで Snowflake ワークシートにて本スクリプトを実行
--   2. Step 5 完了後、PDF を DOCUMENTS_STAGE にアップロードしてから Step 6 以降を実行
--   3. 全ステップ完了後、Streamlit アプリをデプロイ
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- =====================================================
-- Step 1: ロール・ウェアハウス・データベース・スキーマ
-- =====================================================

CREATE OR REPLACE ROLE BANK_BPR_ADMIN_ROLE
  COMMENT = '財務BPR AIプロジェクト管理者ロール';

CREATE OR REPLACE ROLE BANK_BPR_AGENT_ROLE
  COMMENT = '財務BPR AIエージェント実行ロール';

GRANT ROLE BANK_BPR_AGENT_ROLE TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT ROLE BANK_BPR_ADMIN_ROLE TO ROLE SYSADMIN;

CREATE OR REPLACE WAREHOUSE BANK_BPR_WH
  WITH
  WAREHOUSE_SIZE = 'X-SMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = '財務BPR AIプロジェクト用ウェアハウス';

GRANT USAGE ON WAREHOUSE BANK_BPR_WH TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE BANK_BPR_WH TO ROLE BANK_BPR_AGENT_ROLE;
GRANT OPERATE ON WAREHOUSE BANK_BPR_WH TO ROLE BANK_BPR_ADMIN_ROLE;

USE WAREHOUSE BANK_BPR_WH;

CREATE DATABASE IF NOT EXISTS BANK_BPR_DB;
USE DATABASE BANK_BPR_DB;

CREATE OR REPLACE SCHEMA ANALYTICS;
USE SCHEMA ANALYTICS;

-- 管理者ロールへの権限
GRANT USAGE ON DATABASE BANK_BPR_DB TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT USAGE ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT CREATE TABLE ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT CREATE VIEW ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT CREATE STAGE ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT CREATE SEMANTIC VIEW ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;
GRANT CREATE CORTEX SEARCH SERVICE ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;

-- エージェントロールへの権限
GRANT USAGE ON DATABASE BANK_BPR_DB TO ROLE BANK_BPR_AGENT_ROLE;
GRANT USAGE ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE BANK_BPR_AGENT_ROLE;

-- 現在のユーザーにロールを付与
SET current_user = (SELECT CURRENT_USER());
GRANT ROLE BANK_BPR_ADMIN_ROLE TO USER IDENTIFIER($current_user);

-- =====================================================
-- Step 2: ステージ作成
-- =====================================================

CREATE OR REPLACE STAGE BANK_BPR_DB.ANALYTICS.DOCUMENTS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = '規程PDF・決算資料の格納ステージ';

GRANT READ ON STAGE BANK_BPR_DB.ANALYTICS.DOCUMENTS_STAGE TO ROLE BANK_BPR_AGENT_ROLE;

-- =====================================================
-- Step 3: テーブル作成
-- =====================================================

-- --- 共通マスタ ---

CREATE OR REPLACE TABLE DIM_ACCOUNT (
  ACCOUNT_CODE    VARCHAR(20)   NOT NULL,
  ACCOUNT_NAME    VARCHAR(100)  NOT NULL,
  ACCOUNT_NAME_EN VARCHAR(100),
  ACCOUNT_CATEGORY    VARCHAR(50)  COMMENT '資産/負債/純資産/収益/費用',
  ACCOUNT_SUBCATEGORY VARCHAR(50)  COMMENT '中分類',
  BS_PL_FLAG      VARCHAR(2)    COMMENT 'BS or PL',
  CONSTRAINT pk_dim_account PRIMARY KEY (ACCOUNT_CODE)
);

CREATE OR REPLACE TABLE DIM_DEPARTMENT (
  DEPARTMENT_CODE VARCHAR(10)  NOT NULL,
  DEPARTMENT_NAME VARCHAR(100) NOT NULL,
  DIVISION_CODE   VARCHAR(10),
  DIVISION_NAME   VARCHAR(100) COMMENT '本部名',
  CONSTRAINT pk_dim_department PRIMARY KEY (DEPARTMENT_CODE)
);

CREATE OR REPLACE TABLE DIM_BUSINESS_SEGMENT (
  SEGMENT_CODE VARCHAR(10)  NOT NULL,
  SEGMENT_NAME VARCHAR(100) NOT NULL,
  SEGMENT_TYPE VARCHAR(20)  COMMENT 'セグメント種別',
  CONSTRAINT pk_dim_segment PRIMARY KEY (SEGMENT_CODE)
);

CREATE OR REPLACE TABLE DIM_PERIOD (
  PERIOD_ID     VARCHAR(10)  NOT NULL COMMENT 'YYYY-MM形式',
  FISCAL_YEAR   NUMBER(4,0)  NOT NULL,
  FISCAL_PERIOD NUMBER(2,0)  NOT NULL COMMENT '1-12（4月=1）',
  QUARTER       VARCHAR(2)   COMMENT 'Q1-Q4',
  PERIOD_START  DATE,
  PERIOD_END    DATE,
  CONSTRAINT pk_dim_period PRIMARY KEY (PERIOD_ID)
);

-- --- 財務会計ドメイン ---

CREATE OR REPLACE TABLE FACT_JOURNAL_ENTRIES (
  JOURNAL_ID      VARCHAR(20)    NOT NULL,
  POSTING_DATE    DATE           NOT NULL,
  FISCAL_YEAR     NUMBER(4,0)    NOT NULL,
  FISCAL_PERIOD   NUMBER(2,0)    NOT NULL,
  ACCOUNT_CODE    VARCHAR(20)    NOT NULL,
  DEPARTMENT_CODE VARCHAR(10)    NOT NULL,
  DEBIT_AMOUNT    NUMBER(18,2)   DEFAULT 0,
  CREDIT_AMOUNT   NUMBER(18,2)   DEFAULT 0,
  CURRENCY_CODE   VARCHAR(3)     DEFAULT 'JPY',
  JOURNAL_TYPE    VARCHAR(20)    NOT NULL COMMENT '通常/決算補正/連結消去',
  SOURCE_SYSTEM   VARCHAR(50),
  DESCRIPTION     VARCHAR(500),
  CONSTRAINT pk_journal PRIMARY KEY (JOURNAL_ID)
);

CREATE OR REPLACE TABLE FACT_BUDGET (
  BUDGET_ID             VARCHAR(20)  NOT NULL,
  FISCAL_YEAR           NUMBER(4,0)  NOT NULL,
  FISCAL_PERIOD         NUMBER(2,0)  NOT NULL,
  ACCOUNT_CODE          VARCHAR(20)  NOT NULL,
  DEPARTMENT_CODE       VARCHAR(10)  NOT NULL,
  BUDGET_AMOUNT         NUMBER(18,2) DEFAULT 0,
  REVISED_BUDGET_AMOUNT NUMBER(18,2) DEFAULT 0,
  BUDGET_VERSION        VARCHAR(20)  DEFAULT '当初' COMMENT '当初/修正1次/修正2次',
  CONSTRAINT pk_budget PRIMARY KEY (BUDGET_ID)
);

-- --- 管理会計ドメイン ---

CREATE OR REPLACE TABLE FACT_SEGMENT_PL (
  PL_ID             VARCHAR(20)  NOT NULL,
  FISCAL_YEAR       NUMBER(4,0)  NOT NULL,
  FISCAL_PERIOD     NUMBER(2,0)  NOT NULL,
  SEGMENT_CODE      VARCHAR(10)  NOT NULL,
  PL_ITEM_CODE      VARCHAR(20)  NOT NULL,
  PL_ITEM_NAME      VARCHAR(100) NOT NULL,
  FINANCIAL_AMOUNT  NUMBER(18,2) DEFAULT 0 COMMENT '財務会計金額',
  MANAGEMENT_AMOUNT NUMBER(18,2) DEFAULT 0 COMMENT '管理会計金額',
  VARIANCE_AMOUNT   NUMBER(18,2) DEFAULT 0 COMMENT '財管差（= FINANCIAL - MANAGEMENT）',
  CONSTRAINT pk_segment_pl PRIMARY KEY (PL_ID)
);

CREATE OR REPLACE TABLE FACT_TRANSFER_PRICING (
  TP_ID             VARCHAR(20)  NOT NULL,
  FISCAL_YEAR       NUMBER(4,0)  NOT NULL,
  FISCAL_PERIOD     NUMBER(2,0)  NOT NULL,
  FROM_SEGMENT_CODE VARCHAR(10)  NOT NULL,
  TO_SEGMENT_CODE   VARCHAR(10)  NOT NULL,
  TP_TYPE           VARCHAR(50)  NOT NULL COMMENT '金利仕切り/為替仕切り/手数料仕切り',
  TP_AMOUNT         NUMBER(18,2) DEFAULT 0,
  TP_RATE           NUMBER(10,6),
  CONSTRAINT pk_tp PRIMARY KEY (TP_ID)
);

-- --- Cortex Search 用チャンクテーブル ---

CREATE OR REPLACE TABLE REGULATION_CHUNKS (
  CHUNK_ID       NUMBER AUTOINCREMENT,
  DOC_TITLE      VARCHAR(500),
  RELATIVE_PATH  VARCHAR(500),
  CHUNK_INDEX    NUMBER(10,0),
  CHUNK_TEXT     VARCHAR(16777216),
  CATEGORY       VARCHAR(50) COMMENT '規程/通達/ガイドライン',
  FILE_URL       VARCHAR(1000),
  CONSTRAINT pk_reg_chunk PRIMARY KEY (CHUNK_ID)
);

CREATE OR REPLACE TABLE FINANCIAL_REPORTS_CHUNKS (
  CHUNK_ID       NUMBER AUTOINCREMENT,
  DOC_TITLE      VARCHAR(500),
  RELATIVE_PATH  VARCHAR(500),
  CHUNK_INDEX    NUMBER(10,0),
  CHUNK_TEXT     VARCHAR(16777216),
  REPORT_TYPE    VARCHAR(50) COMMENT '決算短信/当局計表/IR資料',
  FISCAL_YEAR    VARCHAR(10),
  FILE_URL       VARCHAR(1000),
  CONSTRAINT pk_report_chunk PRIMARY KEY (CHUNK_ID)
);

-- =====================================================
-- Step 4: サンプルデータ投入
-- =====================================================

-- --- DIM_PERIOD: 2025年度（2025/4～2026/3） ---
INSERT INTO DIM_PERIOD VALUES ('2025-01', 2025, 1,  'Q1', '2025-04-01', '2025-04-30');
INSERT INTO DIM_PERIOD VALUES ('2025-02', 2025, 2,  'Q1', '2025-05-01', '2025-05-31');
INSERT INTO DIM_PERIOD VALUES ('2025-03', 2025, 3,  'Q1', '2025-06-01', '2025-06-30');
INSERT INTO DIM_PERIOD VALUES ('2025-04', 2025, 4,  'Q2', '2025-07-01', '2025-07-31');
INSERT INTO DIM_PERIOD VALUES ('2025-05', 2025, 5,  'Q2', '2025-08-01', '2025-08-31');
INSERT INTO DIM_PERIOD VALUES ('2025-06', 2025, 6,  'Q2', '2025-09-01', '2025-09-30');
INSERT INTO DIM_PERIOD VALUES ('2025-07', 2025, 7,  'Q3', '2025-10-01', '2025-10-31');
INSERT INTO DIM_PERIOD VALUES ('2025-08', 2025, 8,  'Q3', '2025-11-01', '2025-11-30');
INSERT INTO DIM_PERIOD VALUES ('2025-09', 2025, 9,  'Q3', '2025-12-01', '2025-12-31');
INSERT INTO DIM_PERIOD VALUES ('2025-10', 2025, 10, 'Q4', '2026-01-01', '2026-01-31');
INSERT INTO DIM_PERIOD VALUES ('2025-11', 2025, 11, 'Q4', '2026-02-01', '2026-02-28');
INSERT INTO DIM_PERIOD VALUES ('2025-12', 2025, 12, 'Q4', '2026-03-01', '2026-03-31');

-- --- DIM_BUSINESS_SEGMENT ---
INSERT INTO DIM_BUSINESS_SEGMENT VALUES ('SEG01', 'リテール事業',   '事業セグメント');
INSERT INTO DIM_BUSINESS_SEGMENT VALUES ('SEG02', '市場事業',       '事業セグメント');
INSERT INTO DIM_BUSINESS_SEGMENT VALUES ('SEG03', '法人事業',       '事業セグメント');
INSERT INTO DIM_BUSINESS_SEGMENT VALUES ('SEG04', '信託事業',       '事業セグメント');
INSERT INTO DIM_BUSINESS_SEGMENT VALUES ('SEG05', '不動産事業',     '事業セグメント');

-- --- DIM_DEPARTMENT ---
INSERT INTO DIM_DEPARTMENT VALUES ('D001', '財務企画部',       'DIV01', '経営管理本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D002', 'リテール営業第一部', 'DIV02', 'リテール事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D003', 'リテール営業第二部', 'DIV02', 'リテール事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D004', '市場運用部',       'DIV03', '市場事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D005', 'トレーディング部', 'DIV03', '市場事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D006', '法人営業部',       'DIV04', '法人事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D007', '信託業務部',       'DIV05', '信託事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D008', '不動産事業部',     'DIV06', '不動産事業本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D009', '経理部',           'DIV01', '経営管理本部');
INSERT INTO DIM_DEPARTMENT VALUES ('D010', '総務部',           'DIV07', 'コーポレート本部');

-- --- DIM_ACCOUNT ---
INSERT INTO DIM_ACCOUNT VALUES ('1010', '現金及び預け金',     'Cash and Deposits',          '資産', '流動資産',   'BS');
INSERT INTO DIM_ACCOUNT VALUES ('1020', '有価証券',           'Securities',                 '資産', '投資資産',   'BS');
INSERT INTO DIM_ACCOUNT VALUES ('1030', '貸出金',             'Loans and Bills Discounted', '資産', '貸出資産',   'BS');
INSERT INTO DIM_ACCOUNT VALUES ('2010', '預金',               'Deposits',                   '負債', '流動負債',   'BS');
INSERT INTO DIM_ACCOUNT VALUES ('2020', '借用金',             'Borrowed Money',             '負債', '借入負債',   'BS');
INSERT INTO DIM_ACCOUNT VALUES ('4010', '資金運用収益',       'Interest Income',            '収益', '経常収益',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('4011', '貸出金利息',         'Interest on Loans',          '収益', '資金運用収益', 'PL');
INSERT INTO DIM_ACCOUNT VALUES ('4012', '有価証券利息配当金', 'Interest on Securities',      '収益', '資金運用収益', 'PL');
INSERT INTO DIM_ACCOUNT VALUES ('4020', '信託報酬',           'Trust Fees',                 '収益', '経常収益',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('4030', '役務取引等収益',     'Fees and Commissions Income', '収益', '経常収益',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5010', '資金調達費用',       'Interest Expenses',          '費用', '経常費用',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5011', '預金利息',           'Interest on Deposits',       '費用', '資金調達費用', 'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5020', '営業経費',           'General and Administrative',  '費用', '経常費用',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5021', '人件費',             'Personnel Expenses',         '費用', '営業経費',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5022', '物件費',             'Non-Personnel Expenses',     '費用', '営業経費',   'PL');
INSERT INTO DIM_ACCOUNT VALUES ('5023', '旅費交通費',         'Travel Expenses',            '費用', '営業経費',   'PL');

-- --- FACT_JOURNAL_ENTRIES: 2025年度サンプル仕訳 ---
INSERT INTO FACT_JOURNAL_ENTRIES VALUES
  ('J2025-0001', '2025-04-30', 2025, 1, '4011', 'D004', 1250.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 4月計上'),
  ('J2025-0002', '2025-04-30', 2025, 1, '4012', 'D004', 890.50, 0, 'JPY', '通常', '勘定系TMS', '有価証券利息 4月計上'),
  ('J2025-0003', '2025-04-30', 2025, 1, '5011', 'D001', 0, 320.00, 'JPY', '通常', '勘定系TMS', '預金利息 4月計上'),
  ('J2025-0004', '2025-04-30', 2025, 1, '5020', 'D002', 180.00, 0, 'JPY', '通常', '経費システム', 'リテール営業第一部 営業経費 4月'),
  ('J2025-0005', '2025-04-30', 2025, 1, '5021', 'D001', 450.00, 0, 'JPY', '通常', '人事システム', '財務企画部 人件費 4月'),
  ('J2025-0006', '2025-04-30', 2025, 1, '5022', 'D010', 95.00, 0, 'JPY', '通常', '経費システム', '総務部 物件費 4月'),
  ('J2025-0007', '2025-04-30', 2025, 1, '5023', 'D006', 12.50, 0, 'JPY', '通常', '経費システム', '法人営業部 旅費交通費 4月'),
  ('J2025-0008', '2025-04-30', 2025, 1, '4020', 'D007', 530.00, 0, 'JPY', '通常', '信託システム', '信託報酬 4月計上'),
  ('J2025-0009', '2025-04-30', 2025, 1, '4030', 'D006', 210.00, 0, 'JPY', '通常', '勘定系TMS', '役務取引等収益 4月計上'),
  ('J2025-0010', '2025-05-31', 2025, 2, '4011', 'D004', 1280.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 5月計上'),
  ('J2025-0011', '2025-05-31', 2025, 2, '4012', 'D004', 920.30, 0, 'JPY', '通常', '勘定系TMS', '有価証券利息 5月計上'),
  ('J2025-0012', '2025-05-31', 2025, 2, '5011', 'D001', 0, 335.00, 'JPY', '通常', '勘定系TMS', '預金利息 5月計上'),
  ('J2025-0013', '2025-05-31', 2025, 2, '5020', 'D003', 165.00, 0, 'JPY', '通常', '経費システム', 'リテール営業第二部 営業経費 5月'),
  ('J2025-0014', '2025-05-31', 2025, 2, '5021', 'D004', 380.00, 0, 'JPY', '通常', '人事システム', '市場運用部 人件費 5月'),
  ('J2025-0015', '2025-05-31', 2025, 2, '4020', 'D007', 545.00, 0, 'JPY', '通常', '信託システム', '信託報酬 5月計上'),
  ('J2025-0016', '2025-05-31', 2025, 2, '4030', 'D006', 225.00, 0, 'JPY', '通常', '勘定系TMS', '役務取引等収益 5月計上'),
  ('J2025-0017', '2025-06-30', 2025, 3, '4011', 'D004', 1310.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 6月計上'),
  ('J2025-0018', '2025-06-30', 2025, 3, '5020', 'D002', 195.00, 0, 'JPY', '通常', '経費システム', 'リテール営業第一部 営業経費 6月'),
  ('J2025-0019', '2025-06-30', 2025, 3, '5023', 'D006', 18.50, 0, 'JPY', '通常', '経費システム', '法人営業部 旅費交通費 6月'),
  ('J2025-0020', '2025-06-30', 2025, 3, '4020', 'D007', 560.00, 0, 'JPY', '通常', '信託システム', '信託報酬 6月計上'),
  ('J2025-C01', '2025-06-30', 2025, 3, '5020', 'D001', 42.00, 0, 'JPY', '決算補正', '手動入力', 'Q1決算補正 経費未払計上'),
  ('J2025-C02', '2025-06-30', 2025, 3, '4012', 'D004', 15.00, 0, 'JPY', '決算補正', '手動入力', 'Q1決算補正 有価証券評価益'),
  ('J2025-0021', '2025-07-31', 2025, 4, '4011', 'D004', 1350.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 7月計上'),
  ('J2025-0022', '2025-07-31', 2025, 4, '4012', 'D004', 950.00, 0, 'JPY', '通常', '勘定系TMS', '有価証券利息 7月計上'),
  ('J2025-0023', '2025-07-31', 2025, 4, '5020', 'D005', 88.00, 0, 'JPY', '通常', '経費システム', 'トレーディング部 営業経費 7月'),
  ('J2025-0024', '2025-08-31', 2025, 5, '4011', 'D004', 1290.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 8月計上'),
  ('J2025-0025', '2025-08-31', 2025, 5, '5020', 'D008', 75.00, 0, 'JPY', '通常', '経費システム', '不動産事業部 営業経費 8月'),
  ('J2025-0026', '2025-09-30', 2025, 6, '4011', 'D004', 1320.00, 0, 'JPY', '通常', '勘定系TMS', '貸出金利息 9月計上'),
  ('J2025-0027', '2025-09-30', 2025, 6, '5020', 'D002', 205.00, 0, 'JPY', '通常', '経費システム', 'リテール営業第一部 営業経費 9月'),
  ('J2025-C03', '2025-09-30', 2025, 6, '5020', 'D001', 38.00, 0, 'JPY', '決算補正', '手動入力', 'Q2決算補正 経費未払計上'),
  ('J2025-C04', '2025-09-30', 2025, 6, '4012', 'D004', 0, 22.00, 'JPY', '決算補正', '手動入力', 'Q2決算補正 有価証券評価損');

-- --- FACT_BUDGET: 2025年度 予算データ ---
INSERT INTO FACT_BUDGET VALUES ('B2025-001', 2025, 1, '5020', 'D001', 500.00, 500.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-002', 2025, 1, '5020', 'D002', 200.00, 200.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-003', 2025, 1, '5020', 'D003', 180.00, 180.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-004', 2025, 1, '5020', 'D004', 150.00, 150.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-005', 2025, 1, '5020', 'D005', 100.00, 100.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-006', 2025, 1, '5020', 'D006', 120.00, 120.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-007', 2025, 2, '5020', 'D001', 500.00, 480.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-008', 2025, 2, '5020', 'D002', 200.00, 190.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-009', 2025, 2, '5020', 'D003', 180.00, 170.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-010', 2025, 3, '5020', 'D001', 500.00, 500.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-011', 2025, 3, '5020', 'D002', 200.00, 200.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-012', 2025, 4, '5020', 'D004', 150.00, 160.00, '修正1次');
INSERT INTO FACT_BUDGET VALUES ('B2025-013', 2025, 4, '5020', 'D005', 100.00, 100.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-014', 2025, 5, '5020', 'D008', 80.00, 80.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-015', 2025, 6, '5020', 'D002', 200.00, 210.00, '修正1次');
INSERT INTO FACT_BUDGET VALUES ('B2025-016', 2025, 1, '4011', 'D004', 1200.00, 1200.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-017', 2025, 2, '4011', 'D004', 1250.00, 1250.00, '当初');
INSERT INTO FACT_BUDGET VALUES ('B2025-018', 2025, 3, '4011', 'D004', 1300.00, 1300.00, '当初');

-- --- FACT_SEGMENT_PL: 2025年度 Q1-Q2 事業別損益 ---
INSERT INTO FACT_SEGMENT_PL VALUES
  ('PL2025-001', 2025, 1, 'SEG01', '4010', '資金運用収益',       620.00,  580.00,  40.00),
  ('PL2025-002', 2025, 1, 'SEG01', '5010', '資金調達費用',       210.00,  195.00,  15.00),
  ('PL2025-003', 2025, 1, 'SEG01', '5020', '営業経費',           345.00,  345.00,  0.00),
  ('PL2025-004', 2025, 1, 'SEG02', '4010', '資金運用収益',       2140.50, 2250.00, -109.50),
  ('PL2025-005', 2025, 1, 'SEG02', '5010', '資金調達費用',       980.00,  1050.00, -70.00),
  ('PL2025-006', 2025, 1, 'SEG02', '5020', '営業経費',           275.00,  275.00,  0.00),
  ('PL2025-007', 2025, 1, 'SEG03', '4030', '役務取引等収益',     210.00,  200.00,  10.00),
  ('PL2025-008', 2025, 1, 'SEG03', '5020', '営業経費',           132.50,  132.50,  0.00),
  ('PL2025-009', 2025, 1, 'SEG04', '4020', '信託報酬',           530.00,  530.00,  0.00),
  ('PL2025-010', 2025, 1, 'SEG04', '5020', '営業経費',           185.00,  185.00,  0.00),
  ('PL2025-011', 2025, 2, 'SEG01', '4010', '資金運用収益',       640.00,  595.00,  45.00),
  ('PL2025-012', 2025, 2, 'SEG02', '4010', '資金運用収益',       2200.30, 2310.00, -109.70),
  ('PL2025-013', 2025, 2, 'SEG02', '5020', '営業経費',           280.00,  280.00,  0.00),
  ('PL2025-014', 2025, 2, 'SEG03', '4030', '役務取引等収益',     225.00,  215.00,  10.00),
  ('PL2025-015', 2025, 2, 'SEG04', '4020', '信託報酬',           545.00,  545.00,  0.00),
  ('PL2025-016', 2025, 3, 'SEG01', '4010', '資金運用収益',       660.00,  610.00,  50.00),
  ('PL2025-017', 2025, 3, 'SEG02', '4010', '資金運用収益',       2310.00, 2420.00, -110.00),
  ('PL2025-018', 2025, 3, 'SEG04', '4020', '信託報酬',           560.00,  560.00,  0.00),
  ('PL2025-019', 2025, 4, 'SEG02', '4010', '資金運用収益',       2300.00, 2400.00, -100.00),
  ('PL2025-020', 2025, 5, 'SEG02', '4010', '資金運用収益',       2240.00, 2350.00, -110.00),
  ('PL2025-021', 2025, 6, 'SEG02', '4010', '資金運用収益',       2320.00, 2430.00, -110.00);

-- --- FACT_TRANSFER_PRICING: 社内仕切り ---
INSERT INTO FACT_TRANSFER_PRICING VALUES
  ('TP2025-001', 2025, 1, 'SEG01', 'SEG02', '金利仕切り',   45.00,  0.005000),
  ('TP2025-002', 2025, 1, 'SEG02', 'SEG01', '金利仕切り',  -45.00,  0.005000),
  ('TP2025-003', 2025, 1, 'SEG03', 'SEG02', '為替仕切り',   12.00,  110.500000),
  ('TP2025-004', 2025, 1, 'SEG02', 'SEG03', '為替仕切り',  -12.00,  110.500000),
  ('TP2025-005', 2025, 2, 'SEG01', 'SEG02', '金利仕切り',   48.00,  0.005200),
  ('TP2025-006', 2025, 2, 'SEG02', 'SEG01', '金利仕切り',  -48.00,  0.005200),
  ('TP2025-007', 2025, 2, 'SEG04', 'SEG02', '手数料仕切り', 8.50,   0.000000),
  ('TP2025-008', 2025, 2, 'SEG02', 'SEG04', '手数料仕切り', -8.50,  0.000000),
  ('TP2025-009', 2025, 3, 'SEG01', 'SEG02', '金利仕切り',   50.00,  0.005300),
  ('TP2025-010', 2025, 3, 'SEG02', 'SEG01', '金利仕切り',  -50.00,  0.005300);

-- =====================================================
-- Step 5: セマンティックビュー作成
-- =====================================================

-- --- 財務会計セマンティックビュー ---
CREATE OR REPLACE SEMANTIC VIEW BANK_BPR_DB.ANALYTICS.SV_FINANCIAL_ACCOUNTING

  COMMENT = '財務会計分析用セマンティックビュー。仕訳明細・予算データを対象とし、予算消化率分析、GL残高照会、決算補正管理を行う。'

  TABLES (
    journal AS BANK_BPR_DB.ANALYTICS.FACT_JOURNAL_ENTRIES PRIMARY KEY (JOURNAL_ID),
    budget  AS BANK_BPR_DB.ANALYTICS.FACT_BUDGET          PRIMARY KEY (BUDGET_ID),
    account AS BANK_BPR_DB.ANALYTICS.DIM_ACCOUNT          PRIMARY KEY (ACCOUNT_CODE)
      WITH SYNONYMS = ('勘定科目マスタ', '科目マスタ'),
    dept    AS BANK_BPR_DB.ANALYTICS.DIM_DEPARTMENT       PRIMARY KEY (DEPARTMENT_CODE)
      WITH SYNONYMS = ('部門マスタ', '組織マスタ'),
    period  AS BANK_BPR_DB.ANALYTICS.DIM_PERIOD           PRIMARY KEY (PERIOD_ID)
      WITH SYNONYMS = ('会計期間', '期間マスタ')
  )

  RELATIONSHIPS (
    journal (ACCOUNT_CODE)    REFERENCES account,
    journal (DEPARTMENT_CODE) REFERENCES dept,
    budget  (ACCOUNT_CODE)    REFERENCES account,
    budget  (DEPARTMENT_CODE) REFERENCES dept
  )

  FACTS (
    journal.journal_id     AS JOURNAL_ID
      WITH SYNONYMS = ('仕訳ID', '仕訳番号'),
    journal.debit_amount   AS DEBIT_AMOUNT
      WITH SYNONYMS = ('借方', '借方金額', 'debit')
      COMMENT = '借方金額（百万円）',
    journal.credit_amount  AS CREDIT_AMOUNT
      WITH SYNONYMS = ('貸方', '貸方金額', 'credit')
      COMMENT = '貸方金額（百万円）',
    journal.fiscal_year    AS JOURNAL_FISCAL_YEAR
      WITH SYNONYMS = ('会計年度', '年度'),
    journal.fiscal_period  AS JOURNAL_FISCAL_PERIOD
      WITH SYNONYMS = ('会計期間', '月度'),
    budget.budget_id       AS BUDGET_ID,
    budget.budget_amount   AS BUDGET_AMOUNT
      WITH SYNONYMS = ('予算', '予算額', '計画値', '当初予算')
      COMMENT = '予算金額（百万円）',
    budget.revised_budget_amount AS REVISED_BUDGET_AMOUNT
      WITH SYNONYMS = ('修正予算', '改定予算')
      COMMENT = '修正後予算金額（百万円）',
    budget.fiscal_year     AS BUDGET_FISCAL_YEAR,
    budget.fiscal_period   AS BUDGET_FISCAL_PERIOD
  )

  DIMENSIONS (
    account.account_code       AS ACCOUNT_CODE
      WITH SYNONYMS = ('勘定コード', '科目コード'),
    account.account_name       AS ACCOUNT_NAME
      WITH SYNONYMS = ('勘定科目', '科目', '科目名'),
    account.account_category   AS ACCOUNT_CATEGORY
      WITH SYNONYMS = ('勘定区分', '科目区分')
      COMMENT = '資産/負債/純資産/収益/費用',
    account.account_subcategory AS ACCOUNT_SUBCATEGORY
      WITH SYNONYMS = ('勘定中分類', '科目中分類'),
    account.bs_pl_flag         AS BS_PL_FLAG
      WITH SYNONYMS = ('BS/PL区分', '財務諸表区分'),
    dept.department_code       AS DEPARTMENT_CODE
      WITH SYNONYMS = ('部門コード', '部署コード'),
    dept.department_name       AS DEPARTMENT_NAME
      WITH SYNONYMS = ('部門', '部署', '組織'),
    dept.division_name         AS DIVISION_NAME
      WITH SYNONYMS = ('本部', '本部名', '事業本部'),
    journal.posting_date       AS POSTING_DATE
      WITH SYNONYMS = ('計上日', '仕訳日', '記帳日'),
    journal.journal_type       AS JOURNAL_TYPE
      WITH SYNONYMS = ('仕訳種別', '仕訳タイプ', '決算補正', '補正仕訳', '決算整理')
      COMMENT = '通常/決算補正/連結消去',
    journal.source_system      AS SOURCE_SYSTEM
      WITH SYNONYMS = ('発生元', 'ソースシステム'),
    journal.description        AS JOURNAL_DESCRIPTION
      WITH SYNONYMS = ('摘要', '仕訳摘要', '説明'),
    journal.currency_code      AS CURRENCY_CODE
      WITH SYNONYMS = ('通貨', '通貨コード'),
    budget.budget_version      AS BUDGET_VERSION
      WITH SYNONYMS = ('予算バージョン', '予算版'),
    period.quarter             AS QUARTER
      WITH SYNONYMS = ('四半期', 'Q')
  )

  METRICS (
    journal.total_debit  AS SUM(journal.debit_amount)
      WITH SYNONYMS = ('借方合計', '借方総額')
      COMMENT = '借方金額の合計',
    journal.total_credit AS SUM(journal.credit_amount)
      WITH SYNONYMS = ('貸方合計', '貸方総額')
      COMMENT = '貸方金額の合計',
    journal.net_amount   AS SUM(journal.debit_amount) - SUM(journal.credit_amount)
      WITH SYNONYMS = ('純額', '差引額')
      COMMENT = '借方 - 貸方の純額',
    journal.journal_count AS COUNT(journal.journal_id)
      WITH SYNONYMS = ('仕訳件数', '件数'),
    budget.total_budget  AS SUM(budget.budget_amount)
      WITH SYNONYMS = ('予算合計', '予算総額')
  )

  AI_SQL_GENERATION '
    会計年度は4月始まり3月末である。会計期間の FISCAL_PERIOD=1 は4月を意味する。
    四半期は Q1(4-6月, period 1-3), Q2(7-9月, period 4-6), Q3(10-12月, period 7-9), Q4(1-3月, period 10-12)。
    「今期」「当期」は FISCAL_YEAR = 2025 を指す。「前期」は FISCAL_YEAR = 2024。
    金額は百万円単位で格納されている。
    予算消化率は 実績借方合計 / 予算合計 × 100 で計算する。

    部門コード対応表（フィルタ時は DEPARTMENT_CODE を使うこと）:
      D001 = 財務企画部, D002 = リテール営業第一部, D003 = リテール営業第二部,
      D004 = 市場運用部, D005 = トレーディング部, D006 = 法人営業部,
      D007 = 信託業務部, D008 = 不動産事業部, D009 = 経理部, D010 = 総務部
    部門分析では DIVISION_NAME（本部）レベルを優先し、詳細を求められた場合に DEPARTMENT_NAME（部門）に展開する。

    勘定科目コード対応表（フィルタ時は ACCOUNT_CODE を使うこと）:
      4011 = 貸出金利息, 4012 = 有価証券利息, 4020 = 信託報酬,
      4030 = 役務取引等収益, 5011 = 預金利息, 5020 = 営業経費,
      5021 = 人件費, 5022 = 物件費, 5023 = 旅費交通費, 5024 = 交際費

    日本語の名称でフィルタする代わりに、上記のコード値で WHERE 条件を構成すること。
    決算補正仕訳は JOURNAL_TYPE = ''決算補正'' でフィルタする。
  '
;

-- --- 管理会計セマンティックビュー ---
CREATE OR REPLACE SEMANTIC VIEW BANK_BPR_DB.ANALYTICS.SV_MANAGEMENT_ACCOUNTING

  COMMENT = '管理会計分析用セマンティックビュー。事業別損益・社内仕切り・財管差分析に特化。'

  TABLES (
    seg_pl  AS BANK_BPR_DB.ANALYTICS.FACT_SEGMENT_PL       PRIMARY KEY (PL_ID),
    tp      AS BANK_BPR_DB.ANALYTICS.FACT_TRANSFER_PRICING  PRIMARY KEY (TP_ID),
    segment AS BANK_BPR_DB.ANALYTICS.DIM_BUSINESS_SEGMENT   PRIMARY KEY (SEGMENT_CODE)
      WITH SYNONYMS = ('事業セグメント', 'セグメントマスタ'),
    period  AS BANK_BPR_DB.ANALYTICS.DIM_PERIOD             PRIMARY KEY (PERIOD_ID)
      WITH SYNONYMS = ('会計期間', '期間マスタ')
  )

  RELATIONSHIPS (
    seg_pl (SEGMENT_CODE)      REFERENCES segment
  )

  FACTS (
    seg_pl.pl_id              AS PL_ID,
    seg_pl.fiscal_year        AS PL_FISCAL_YEAR
      WITH SYNONYMS = ('会計年度', '年度'),
    seg_pl.fiscal_period      AS PL_FISCAL_PERIOD
      WITH SYNONYMS = ('会計期間', '月度'),
    seg_pl.financial_amount   AS FINANCIAL_AMOUNT
      WITH SYNONYMS = ('財務会計金額', '制度会計金額', '財務金額')
      COMMENT = '財務会計ベースの金額（百万円）',
    seg_pl.management_amount  AS MANAGEMENT_AMOUNT
      WITH SYNONYMS = ('管理会計金額', '事業損益', '管理金額')
      COMMENT = '管理会計ベースの金額（百万円）',
    seg_pl.variance_amount    AS VARIANCE_AMOUNT
      WITH SYNONYMS = ('財管差', '差額', '差異', '乖離', 'ギャップ')
      COMMENT = '財管差 = 財務会計金額 - 管理会計金額',
    tp.tp_id                  AS TP_ID,
    tp.fiscal_year            AS TP_FISCAL_YEAR,
    tp.fiscal_period          AS TP_FISCAL_PERIOD,
    tp.tp_amount              AS TP_AMOUNT
      WITH SYNONYMS = ('社内仕切り', '移転価格', 'TP', '仕切り金額')
      COMMENT = '社内仕切り金額（百万円）',
    tp.tp_rate                AS TP_RATE
      WITH SYNONYMS = ('仕切りレート', '適用レート', 'TPレート')
  )

  DIMENSIONS (
    segment.segment_code   AS SEGMENT_CODE
      WITH SYNONYMS = ('セグメントコード', '事業コード'),
    segment.segment_name   AS SEGMENT_NAME
      WITH SYNONYMS = ('セグメント', '事業', '事業部門', 'ビジネスライン',
                        'リテール事業', '市場事業', '法人事業', '信託事業', '不動産事業')
      COMMENT = '値: リテール事業 / 市場事業 / 法人事業 / 信託事業 / 不動産事業',
    seg_pl.pl_item_code    AS PL_ITEM_CODE
      WITH SYNONYMS = ('PL項目コード', '損益項目コード'),
    seg_pl.pl_item_name    AS PL_ITEM_NAME
      WITH SYNONYMS = ('PL項目', '損益項目', '勘定'),
    tp.from_segment_code   AS FROM_SEGMENT_CODE
      WITH SYNONYMS = ('支払元セグメント', '仕切り元'),
    tp.to_segment_code     AS TO_SEGMENT_CODE
      WITH SYNONYMS = ('受取先セグメント', '仕切り先'),
    tp.tp_type             AS TP_TYPE
      WITH SYNONYMS = ('仕切り種別', '仕切りタイプ')
      COMMENT = '金利仕切り/為替仕切り/手数料仕切り',
    period.quarter         AS QUARTER
      WITH SYNONYMS = ('四半期', 'Q')
  )

  METRICS (
    seg_pl.total_financial  AS SUM(seg_pl.financial_amount)
      WITH SYNONYMS = ('財務会計合計', '制度会計合計')
      COMMENT = '財務会計金額の合計',
    seg_pl.total_management AS SUM(seg_pl.management_amount)
      WITH SYNONYMS = ('管理会計合計', '事業損益合計')
      COMMENT = '管理会計金額の合計',
    seg_pl.total_variance   AS SUM(seg_pl.variance_amount)
      WITH SYNONYMS = ('財管差合計', '差異合計')
      COMMENT = '財管差の合計',
    tp.total_tp             AS SUM(tp.tp_amount)
      WITH SYNONYMS = ('社内仕切り合計', 'TP合計')
      COMMENT = '社内仕切り金額の合計',
    seg_pl.segment_pl_count AS COUNT(seg_pl.pl_id)
      WITH SYNONYMS = ('PL明細件数', '件数')
  )

  AI_SQL_GENERATION '
    財管差 = 財務会計金額 - 管理会計金額（VARIANCE_AMOUNT として格納済み）。
    社内仕切りは金利仕切り・為替仕切り・手数料仕切りの3種類がある。

    事業セグメントのコード対応表（フィルタ時は必ず SEGMENT_CODE を使うこと）:
      SEG01 = リテール事業
      SEG02 = 市場事業
      SEG03 = 法人事業
      SEG04 = 信託事業
      SEG05 = 不動産事業
    例: 「リテール事業と市場事業を比較」→ WHERE segment.SEGMENT_CODE IN (''SEG01'', ''SEG02'')
    SEGMENT_NAME での文字列フィルタは避け、SEGMENT_CODE で絞り込むこと。

    セグメント間のTP受払はネットゼロになるべき。
    「今期」は FISCAL_YEAR = 2025。金額は百万円単位。
    会計年度は4月始まり3月末。FISCAL_PERIOD=1 は4月。
    四半期は Q1(period 1-3), Q2(period 4-6), Q3(period 7-9), Q4(period 10-12)。
  '
;

-- =====================================================
-- Step 6: Cortex Search Service（PDF パース → チャンク → 検索サービス）
-- =====================================================
-- ┌─────────────────────────────────────────────────────────┐
-- │ ★ ここで一旦停止し、PDF を DOCUMENTS_STAGE にアップロード │
-- │                                                         │
-- │ 方法 1: Snowsight UI                                    │
-- │   Catalog > BANK_BPR_DB > ANALYTICS > Stages            │
-- │   > DOCUMENTS_STAGE > [+ Files]                         │
-- │                                                         │
-- │ 方法 2: SnowSQL                                         │
-- │   PUT file:///path/to/pdfs/regulation_*.pdf              │
-- │       @BANK_BPR_DB.ANALYTICS.DOCUMENTS_STAGE;           │
-- │   PUT file:///path/to/pdfs/financial_report_*.pdf        │
-- │       @BANK_BPR_DB.ANALYTICS.DOCUMENTS_STAGE;           │
-- │                                                         │
-- │ ファイル命名規則:                                        │
-- │   regulation_*.pdf       → 規程・通達として処理           │
-- │   financial_report_*.pdf → 決算資料として処理             │
-- │                                                         │
-- │ PDFアップロード後、以下のステートメントを続けて実行       │
-- └─────────────────────────────────────────────────────────┘

-- PDF パース用に一時的にウェアハウスを拡大
ALTER WAREHOUSE BANK_BPR_WH SET WAREHOUSE_SIZE = '2X-LARGE';

-- --- 規程・通達 PDF の Parse & Chunk ---

CREATE OR REPLACE TABLE REGULATION_DOCUMENTS (
  FILE_NAME     VARCHAR(500),
  CATEGORY      VARCHAR(50),
  CONTENT       VARIANT
);

INSERT INTO REGULATION_DOCUMENTS (FILE_NAME, CATEGORY, CONTENT)
SELECT
  relative_path AS FILE_NAME,
  'regulation'  AS CATEGORY,
  SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
    '@DOCUMENTS_STAGE', relative_path, {'mode': 'LAYOUT'}
  ) AS CONTENT
FROM DIRECTORY('@DOCUMENTS_STAGE')
WHERE relative_path LIKE 'regulation_%';

INSERT INTO REGULATION_CHUNKS (DOC_TITLE, RELATIVE_PATH, CHUNK_INDEX, CHUNK_TEXT, CATEGORY, FILE_URL)
SELECT
  r.FILE_NAME,
  r.FILE_NAME,
  ROW_NUMBER() OVER (PARTITION BY r.FILE_NAME ORDER BY chunks.index) AS CHUNK_INDEX,
  chunks.value::STRING AS CHUNK_TEXT,
  r.CATEGORY,
  GET_PRESIGNED_URL('@DOCUMENTS_STAGE', r.FILE_NAME, 3600) AS FILE_URL
FROM REGULATION_DOCUMENTS r,
LATERAL FLATTEN(
  SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
    r.CONTENT:content::STRING,
    'none',
    1500,
    200
  )
) AS chunks;

-- --- 決算資料 PDF の Parse & Chunk ---

CREATE OR REPLACE TABLE FINANCIAL_REPORTS_DOCUMENTS (
  FILE_NAME     VARCHAR(500),
  REPORT_TYPE   VARCHAR(50),
  FISCAL_YEAR   VARCHAR(10),
  CONTENT       VARIANT
);

INSERT INTO FINANCIAL_REPORTS_DOCUMENTS (FILE_NAME, REPORT_TYPE, FISCAL_YEAR, CONTENT)
SELECT
  relative_path AS FILE_NAME,
  'financial_report' AS REPORT_TYPE,
  SPLIT_PART(SPLIT_PART(relative_path, '_', 3), '.', 1) AS FISCAL_YEAR,
  SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
    '@DOCUMENTS_STAGE', relative_path, {'mode': 'LAYOUT'}
  ) AS CONTENT
FROM DIRECTORY('@DOCUMENTS_STAGE')
WHERE relative_path LIKE 'financial_report_%';

INSERT INTO FINANCIAL_REPORTS_CHUNKS (DOC_TITLE, RELATIVE_PATH, CHUNK_INDEX, CHUNK_TEXT, REPORT_TYPE, FISCAL_YEAR, FILE_URL)
SELECT
  f.FILE_NAME,
  f.FILE_NAME,
  ROW_NUMBER() OVER (PARTITION BY f.FILE_NAME ORDER BY chunks.index) AS CHUNK_INDEX,
  chunks.value::STRING AS CHUNK_TEXT,
  f.REPORT_TYPE,
  f.FISCAL_YEAR,
  GET_PRESIGNED_URL('@DOCUMENTS_STAGE', f.FILE_NAME, 3600) AS FILE_URL
FROM FINANCIAL_REPORTS_DOCUMENTS f,
LATERAL FLATTEN(
  SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
    f.CONTENT:content::STRING,
    'none',
    1500,
    200
  )
) AS chunks;

-- ウェアハウスを元のサイズに縮小
ALTER WAREHOUSE BANK_BPR_WH SET WAREHOUSE_SIZE = 'X-SMALL';

-- --- Cortex Search Service 作成 ---

CREATE OR REPLACE CORTEX SEARCH SERVICE REGULATION_SEARCH_SERVICE
  ON CHUNK_TEXT
  ATTRIBUTES DOC_TITLE, CATEGORY, CHUNK_INDEX, FILE_URL
  WAREHOUSE = BANK_BPR_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT CHUNK_TEXT, DOC_TITLE, CATEGORY, CHUNK_INDEX, FILE_URL
    FROM REGULATION_CHUNKS
  );

CREATE OR REPLACE CORTEX SEARCH SERVICE FINANCIAL_REPORTS_SEARCH_SERVICE
  ON CHUNK_TEXT
  ATTRIBUTES DOC_TITLE, REPORT_TYPE, FISCAL_YEAR, CHUNK_INDEX, FILE_URL
  WAREHOUSE = BANK_BPR_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT CHUNK_TEXT, DOC_TITLE, REPORT_TYPE, FISCAL_YEAR, CHUNK_INDEX, FILE_URL
    FROM FINANCIAL_REPORTS_CHUNKS
  );

-- =====================================================
-- Step 7: 権限付与（RBAC）
-- =====================================================

GRANT SELECT ON ALL TABLES IN SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_AGENT_ROLE;
GRANT REFERENCES ON SEMANTIC VIEW BANK_BPR_DB.ANALYTICS.SV_FINANCIAL_ACCOUNTING TO ROLE BANK_BPR_AGENT_ROLE;
GRANT REFERENCES ON SEMANTIC VIEW BANK_BPR_DB.ANALYTICS.SV_MANAGEMENT_ACCOUNTING TO ROLE BANK_BPR_AGENT_ROLE;

-- =====================================================
-- Step 8: Cortex Agent 作成（CREATE AGENT）
-- =====================================================

GRANT CREATE AGENT ON SCHEMA BANK_BPR_DB.ANALYTICS TO ROLE BANK_BPR_ADMIN_ROLE;

CREATE OR REPLACE AGENT BANK_BPR_DB.ANALYTICS.BANK_FINANCE_AGENT
  COMMENT = '大手信託銀行 財務企画部向け AI アシスタント'
  PROFILE = '{"display_name": "財務 AI アシスタント", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    system: "あなたは大手信託銀行の財務企画部を支援する専門AIアシスタントです。"
    orchestration: >
      クエリの分解と分類:
      - 財務会計データ（仕訳・GL・予算）に関する質問は「財務会計分析」ツールを使用
      - 管理会計データ（事業PL・TP・財管差）に関する質問は「管理会計分析」ツールを使用
      - 規程・通達・経費ルールの照会は「規程検索」ツールを使用
      - 過去の決算資料・報告書テンプレートの参照は「決算資料検索」ツールを使用
      - 複合的な質問は逐次的に各ツールを呼び出し、結果を統合して回答する
    response: >
      あなたは大手信託銀行の財務企画部を支援する専門AIアシスタントです。
      予算管理、収益分析、決算業務、行内規程の照会を行います。

      回答ガイドライン:
      - すべて日本語で回答すること
      - 数値データには必ず前期比・予算比のコメントを付与すること
      - 規程に基づく判断には出典（規程名・条項番号）を明記すること
      - 金額は百万円単位で統一し、変動率は%で表記すること
      - 回答の冒頭に1-2文の要約を記載すること
      - 回答は簡潔かつ包括的であること
    sample_questions:
      - question: "今四半期の営業経費の予算消化率を部門別に表示してください"
      - question: "2025年度のリテール事業と市場事業のPL項目別損益を比較してください"
      - question: "財管差が大きいセグメントと主要勘定を教えてください"
      - question: "今期の決算補正仕訳の一覧を金額降順で表示してください"
      - question: "社内仕切りの影響額をセグメント別に見せてください"

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: "財務会計分析"
        description: >
          財務会計データ（仕訳明細・GL残高・予算）を分析するツール。
          予算消化率、決算補正仕訳一覧、勘定別推移、部門別経費分析などのクエリに対応。
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: "管理会計分析"
        description: >
          管理会計データ（事業別損益・社内仕切り・財管差）を分析するツール。
          セグメント別PL比較、TP影響額計算、財管差要因分析に対応。
    - tool_spec:
        type: cortex_search
        name: "規程検索"
        description: >
          行内規定集、会計処理通達、経費精算ガイドラインのPDFを検索するツール。
          経費処理の妥当性判断や会計ルールの確認に使用。
    - tool_spec:
        type: cortex_search
        name: "決算資料検索"
        description: >
          過去の決算資料、報告書テンプレート、当局提出書類のPDFを検索するツール。
          過去の開示内容の確認や報告書ドラフト作成支援に使用。

  tool_resources:
    財務会計分析:
      semantic_view: "BANK_BPR_DB.ANALYTICS.SV_FINANCIAL_ACCOUNTING"
      execution_environment:
        type: warehouse
        warehouse: "BANK_BPR_WH"
    管理会計分析:
      semantic_view: "BANK_BPR_DB.ANALYTICS.SV_MANAGEMENT_ACCOUNTING"
      execution_environment:
        type: warehouse
        warehouse: "BANK_BPR_WH"
    規程検索:
      name: "BANK_BPR_DB.ANALYTICS.REGULATION_SEARCH_SERVICE"
      max_results: 5
      title_column: "DOC_TITLE"
      id_column: "CHUNK_INDEX"
    決算資料検索:
      name: "BANK_BPR_DB.ANALYTICS.FINANCIAL_REPORTS_SEARCH_SERVICE"
      max_results: 5
      title_column: "DOC_TITLE"
      id_column: "CHUNK_INDEX"
  $$;

-- エージェントロールに Agent の USAGE 権限を付与
GRANT USAGE ON AGENT BANK_BPR_DB.ANALYTICS.BANK_FINANCE_AGENT TO ROLE BANK_BPR_AGENT_ROLE;

SELECT '環境セットアップが完了しました。Snowflake CoWork で BANK_FINANCE_AGENT をお試しください。' AS STATUS;
