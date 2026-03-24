-- =========================================================
-- ネット銀行 与信管理 × Snowflake AI Agent MVP
--
-- 03_sv_setup.sql - Semantic View 作成（Cortex Analyst 用）
-- =========================================================
-- 作成日: 2026/03
-- =========================================================
--
-- ⚠️ 前提条件:
--   - 01_db_setup.sql を先に実行済みであること
--
-- =========================================================

SET DB_NAME    = COALESCE($DB_NAME,    'CREDIT_MGMT_DB');
SET WH_NAME    = COALESCE($WH_NAME,    'CREDIT_MGMT_WH');
SET ADMIN_ROLE = COALESCE($ADMIN_ROLE,  'ACCOUNTADMIN');

USE ROLE IDENTIFIER($ADMIN_ROLE);
USE DATABASE IDENTIFIER($DB_NAME);
USE WAREHOUSE IDENTIFIER($WH_NAME);
USE SCHEMA ANALYTICS;


-- =========================================================
-- Step 1: Semantic View の作成
-- =========================================================
-- SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML を使用して
-- プログラムで Semantic View を作成します。
--
-- 【対象テーブル（7テーブル）】
--   CUSTOMER, LOAN, FINANCIAL_STATEMENT, ACCOUNT_TRANSACTION,
--   COLLATERAL, REPAYMENT, CREDIT_REVIEW
--
-- 【リレーションシップ（4本）】
--   LOAN → CUSTOMER, FINANCIAL_STATEMENT → CUSTOMER,
--   ACCOUNT_TRANSACTION → CUSTOMER, CREDIT_REVIEW → CUSTOMER
--
-- 【注意】
--   LOANテーブルのPKが複合キー(LOAN_ID, RECORD_DATE)のため、
--   COLLATERAL→LOAN, REPAYMENT→LOAN のリレーションシップは
--   SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML では定義不可。
--   VQRのSQLでJOIN条件として担保・返済クエリは正常動作します。

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'CREDIT_MGMT_DB.ANALYTICS',
  $$name: CREDIT_ANALYSIS_SV
description: "ネット銀行の与信管理業務を支援するSemantic View。法人顧客マスタ、融資情報、財務諸表、口座取引、担保情報、返済実績、審査履歴の7テーブルを統合し、融資残高・延滞状況・財務指標・ポートフォリオ分析のKPIを自然言語で分析可能にする。"
tables:
  - name: CUSTOMER
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: CUSTOMER
    primary_key:
      columns:
        - CUSTOMER_ID
    dimensions:
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
        description: 顧客ID
      - name: CUSTOMER_NAME
        expr: CUSTOMER_NAME
        data_type: VARCHAR
        description: 企業名
        synonyms:
          - 顧客名
          - 会社名
          - 取引先名
      - name: CUSTOMER_TYPE
        expr: CUSTOMER_TYPE
        data_type: VARCHAR
        description: 顧客種別
      - name: INDUSTRY_CODE
        expr: INDUSTRY_CODE
        data_type: VARCHAR
        description: 業種コード
      - name: INDUSTRY_NAME
        expr: INDUSTRY_NAME
        data_type: VARCHAR
        description: 業種名
        synonyms:
          - 業種
          - 業界
      - name: SUB_INDUSTRY
        expr: SUB_INDUSTRY
        data_type: VARCHAR
        description: サブ業種
      - name: CAPITAL
        expr: CAPITAL
        data_type: NUMBER
        description: 資本金（百万円）
      - name: EMPLOYEE_COUNT
        expr: EMPLOYEE_COUNT
        data_type: NUMBER
        description: 従業員数
      - name: ANNUAL_REVENUE
        expr: ANNUAL_REVENUE
        data_type: NUMBER
        description: 年間売上高（百万円）
      - name: PREFECTURE
        expr: PREFECTURE
        data_type: VARCHAR
        description: 所在地（都道府県）
      - name: CREDIT_RATING
        expr: CREDIT_RATING
        data_type: VARCHAR
        description: 信用格付
        synonyms:
          - 格付
          - レーティング
      - name: RISK_SEGMENT
        expr: RISK_SEGMENT
        data_type: VARCHAR
        description: リスクセグメント
        synonyms:
          - 債務者区分
      - name: RELATIONSHIP_MANAGER
        expr: RELATIONSHIP_MANAGER
        data_type: VARCHAR
        description: 担当RM
        synonyms:
          - 担当者
          - RM
      - name: BRANCH_NAME
        expr: BRANCH_NAME
        data_type: VARCHAR
        description: 所管部署
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
        description: ステータス
    time_dimensions:
      - name: ESTABLISHED_DATE
        expr: ESTABLISHED_DATE
        data_type: DATE
        description: 設立日
      - name: RATING_DATE
        expr: RATING_DATE
        data_type: DATE
        description: 格付日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
      - name: UPDATED_AT
        expr: UPDATED_AT
        data_type: TIMESTAMP_LTZ
    facts:
      - name: CREDIT_SCORE
        expr: CREDIT_SCORE
        data_type: NUMBER
        description: 信用スコア（0-100）
        synonyms:
          - スコア
  - name: LOAN
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: LOAN
    primary_key:
      columns:
        - LOAN_ID
        - RECORD_DATE
    dimensions:
      - name: LOAN_ID
        expr: LOAN_ID
        data_type: NUMBER
        description: 融資ID
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
        description: 顧客ID
      - name: LOAN_TYPE
        expr: LOAN_TYPE
        data_type: VARCHAR
        description: 融資種別
        synonyms:
          - 貸出種別
      - name: LOAN_PURPOSE
        expr: LOAN_PURPOSE
        data_type: VARCHAR
        description: 資金使途
        synonyms:
          - 使途
      - name: LOAN_PURPOSE_DETAIL
        expr: LOAN_PURPOSE_DETAIL
        data_type: VARCHAR
        description: 資金使途詳細
      - name: LOAN_AMOUNT
        expr: LOAN_AMOUNT
        data_type: NUMBER
        description: 融資実行額（百万円）
        synonyms:
          - 融資額
          - 実行額
      - name: OUTSTANDING_BALANCE
        expr: OUTSTANDING_BALANCE
        data_type: NUMBER
        description: 融資残高（百万円）
        synonyms:
          - 残高
          - 貸出残高
      - name: RATE_TYPE
        expr: RATE_TYPE
        data_type: VARCHAR
        description: 金利種別
      - name: REPAYMENT_METHOD
        expr: REPAYMENT_METHOD
        data_type: VARCHAR
        description: 返済方法
      - name: LOAN_STATUS
        expr: LOAN_STATUS
        data_type: VARCHAR
        description: 融資ステータス
        synonyms:
          - ステータス
          - 状態
      - name: DAYS_PAST_DUE
        expr: DAYS_PAST_DUE
        data_type: NUMBER
        description: 延滞日数
        synonyms:
          - DPD
      - name: ASSET_CLASSIFICATION
        expr: ASSET_CLASSIFICATION
        data_type: VARCHAR
        description: 資産分類
    time_dimensions:
      - name: LOAN_START_DATE
        expr: LOAN_START_DATE
        data_type: DATE
        description: 融資実行日
      - name: LOAN_END_DATE
        expr: LOAN_END_DATE
        data_type: DATE
        description: 融資期限
      - name: RECORD_DATE
        expr: RECORD_DATE
        data_type: DATE
        description: レコード基準日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
    facts:
      - name: INTEREST_RATE
        expr: INTEREST_RATE
        data_type: NUMBER
        description: 適用金利（%）
        synonyms:
          - 金利
  - name: FINANCIAL_STATEMENT
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: FINANCIAL_STATEMENT
    primary_key:
      columns:
        - FS_ID
    dimensions:
      - name: FS_ID
        expr: FS_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: TOTAL_ASSETS
        expr: TOTAL_ASSETS
        data_type: NUMBER
        description: 総資産（百万円）
      - name: NET_ASSETS
        expr: NET_ASSETS
        data_type: NUMBER
        description: 純資産（百万円）
      - name: REVENUE
        expr: REVENUE
        data_type: NUMBER
        description: 売上高（百万円）
        synonyms:
          - 売上
      - name: OPERATING_PROFIT
        expr: OPERATING_PROFIT
        data_type: NUMBER
        description: 営業利益（百万円）
      - name: NET_INCOME
        expr: NET_INCOME
        data_type: NUMBER
        description: 当期純利益（百万円）
        synonyms:
          - 純利益
      - name: CURRENT_ASSETS
        expr: CURRENT_ASSETS
        data_type: NUMBER
        description: 流動資産（百万円）
      - name: CURRENT_LIABILITIES
        expr: CURRENT_LIABILITIES
        data_type: NUMBER
        description: 流動負債（百万円）
      - name: TOTAL_DEBT
        expr: TOTAL_DEBT
        data_type: NUMBER
        description: 有利子負債（百万円）
      - name: CASH_FLOW_OPERATING
        expr: CASH_FLOW_OPERATING
        data_type: NUMBER
        description: 営業キャッシュフロー（百万円）
    time_dimensions:
      - name: FISCAL_YEAR_END
        expr: FISCAL_YEAR_END
        data_type: DATE
        description: 決算期末日
        synonyms:
          - 決算日
          - 決算期
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
    facts:
      - name: EQUITY_RATIO
        expr: EQUITY_RATIO
        data_type: NUMBER
        description: 自己資本比率（%）
      - name: CURRENT_RATIO
        expr: CURRENT_RATIO
        data_type: NUMBER
        description: 流動比率（%）
      - name: DEBT_EQUITY_RATIO
        expr: DEBT_EQUITY_RATIO
        data_type: NUMBER
        description: D/Eレシオ
        synonyms:
          - DEレシオ
      - name: INTEREST_COVERAGE
        expr: INTEREST_COVERAGE
        data_type: NUMBER
        description: インタレストカバレッジレシオ（ICR）
        synonyms:
          - ICR
      - name: ROA
        expr: ROA
        data_type: NUMBER
        description: 総資産利益率（%）
      - name: ROE
        expr: ROE
        data_type: NUMBER
        description: 自己資本利益率（%）
  - name: ACCOUNT_TRANSACTION
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: ACCOUNT_TRANSACTION
    primary_key:
      columns:
        - TXN_ID
    dimensions:
      - name: TXN_ID
        expr: TXN_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: TXN_TYPE
        expr: TXN_TYPE
        data_type: VARCHAR
        description: 取引種別
      - name: AMOUNT
        expr: AMOUNT
        data_type: NUMBER
        description: 取引金額（百万円）
      - name: BALANCE_AFTER
        expr: BALANCE_AFTER
        data_type: NUMBER
        description: 取引後残高（百万円）
      - name: CATEGORY
        expr: CATEGORY
        data_type: VARCHAR
        description: 取引カテゴリ
      - name: MEMO
        expr: MEMO
        data_type: VARCHAR
        description: 摘要
    time_dimensions:
      - name: TXN_DATE
        expr: TXN_DATE
        data_type: DATE
        description: 取引日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
  - name: COLLATERAL
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: COLLATERAL
    primary_key:
      columns:
        - COLLATERAL_ID
    dimensions:
      - name: COLLATERAL_ID
        expr: COLLATERAL_ID
        data_type: NUMBER
      - name: LOAN_ID
        expr: LOAN_ID
        data_type: NUMBER
      - name: COLLATERAL_TYPE
        expr: COLLATERAL_TYPE
        data_type: VARCHAR
        description: 担保種別
        synonyms:
          - 担保種類
      - name: DESCRIPTION
        expr: DESCRIPTION
        data_type: VARCHAR
        description: 担保物件の説明
      - name: APPRAISED_VALUE
        expr: APPRAISED_VALUE
        data_type: NUMBER
        description: 担保評価額（百万円）
        synonyms:
          - 評価額
      - name: SECURED_VALUE
        expr: SECURED_VALUE
        data_type: NUMBER
        description: 担保価値（百万円）
        synonyms:
          - 保全額
    time_dimensions:
      - name: APPRAISAL_DATE
        expr: APPRAISAL_DATE
        data_type: DATE
        description: 評価日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
    facts:
      - name: HAIRCUT_RATE
        expr: HAIRCUT_RATE
        data_type: NUMBER
        description: 担保掛目（%）
  - name: REPAYMENT
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: REPAYMENT
    primary_key:
      columns:
        - REPAYMENT_ID
    dimensions:
      - name: REPAYMENT_ID
        expr: REPAYMENT_ID
        data_type: NUMBER
      - name: LOAN_ID
        expr: LOAN_ID
        data_type: NUMBER
      - name: DUE_AMOUNT
        expr: DUE_AMOUNT
        data_type: NUMBER
        description: 約定返済額（百万円）
      - name: ACTUAL_AMOUNT
        expr: ACTUAL_AMOUNT
        data_type: NUMBER
        description: 実返済額（百万円）
      - name: PRINCIPAL_PORTION
        expr: PRINCIPAL_PORTION
        data_type: NUMBER
        description: 元本返済額（百万円）
      - name: INTEREST_PORTION
        expr: INTEREST_PORTION
        data_type: NUMBER
        description: 利息返済額（百万円）
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
        description: 返済ステータス
    time_dimensions:
      - name: DUE_DATE
        expr: DUE_DATE
        data_type: DATE
        description: 約定日
      - name: ACTUAL_DATE
        expr: ACTUAL_DATE
        data_type: DATE
        description: 実返済日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
  - name: CREDIT_REVIEW
    base_table:
      database: CREDIT_MGMT_DB
      schema: CREDIT_DATA
      table: CREDIT_REVIEW
    primary_key:
      columns:
        - REVIEW_ID
    dimensions:
      - name: REVIEW_ID
        expr: REVIEW_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: LOAN_ID
        expr: LOAN_ID
        data_type: NUMBER
      - name: REVIEW_TYPE
        expr: REVIEW_TYPE
        data_type: VARCHAR
        description: 審査種別
      - name: PREVIOUS_RATING
        expr: PREVIOUS_RATING
        data_type: VARCHAR
        description: 変更前格付
      - name: NEW_RATING
        expr: NEW_RATING
        data_type: VARCHAR
        description: 変更後格付
      - name: DECISION
        expr: DECISION
        data_type: VARCHAR
        description: 審査結果
      - name: REVIEWER
        expr: REVIEWER
        data_type: VARCHAR
        description: 審査担当者
      - name: APPROVER
        expr: APPROVER
        data_type: VARCHAR
        description: 承認者
      - name: REVIEW_COMMENT
        expr: REVIEW_COMMENT
        data_type: VARCHAR
        description: 審査コメント
      - name: RISK_FACTORS
        expr: RISK_FACTORS
        data_type: VARCHAR
        description: リスク要因
      - name: CONDITIONS
        expr: CONDITIONS
        data_type: VARCHAR
        description: 条件事項
    time_dimensions:
      - name: REVIEW_DATE
        expr: REVIEW_DATE
        data_type: DATE
        description: 審査日
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_LTZ
relationships:
  - name: LOAN_TO_CUSTOMER
    left_table: LOAN
    right_table: CUSTOMER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: FINANCIAL_STATEMENT_TO_CUSTOMER
    left_table: FINANCIAL_STATEMENT
    right_table: CUSTOMER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: ACCOUNT_TRANSACTION_TO_CUSTOMER
    left_table: ACCOUNT_TRANSACTION
    right_table: CUSTOMER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: CREDIT_REVIEW_TO_CUSTOMER
    left_table: CREDIT_REVIEW
    right_table: CUSTOMER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
verified_queries:
  - name: top_10_loan_balance
    question: 融資残高が大きい企業トップ10を教えてください
    sql: "SELECT c.CUSTOMER_NAME, c.INDUSTRY_NAME, c.CREDIT_RATING, SUM(l.OUTSTANDING_BALANCE) AS TOTAL_BALANCE, COUNT(l.LOAN_ID) AS LOAN_COUNT FROM CUSTOMER AS c JOIN LOAN AS l ON c.CUSTOMER_ID = l.CUSTOMER_ID WHERE l.RECORD_DATE = '2025-01-31' GROUP BY c.CUSTOMER_NAME, c.INDUSTRY_NAME, c.CREDIT_RATING ORDER BY TOTAL_BALANCE DESC LIMIT 10"
    verified_at: 1774320823
    verified_by: Semantic Model Generator
  - name: delinquent_loans
    question: 延滞が発生している融資先と延滞日数を教えてください
    sql: "SELECT c.CUSTOMER_NAME, c.CREDIT_RATING, c.RISK_SEGMENT, l.LOAN_PURPOSE, l.OUTSTANDING_BALANCE, l.DAYS_PAST_DUE, l.ASSET_CLASSIFICATION FROM LOAN AS l JOIN CUSTOMER AS c ON l.CUSTOMER_ID = c.CUSTOMER_ID WHERE l.LOAN_STATUS IN ('延滞', '条件変更') AND l.RECORD_DATE = '2025-01-31' ORDER BY l.DAYS_PAST_DUE DESC"
    verified_at: 1774320823
    verified_by: Semantic Model Generator
  - name: financial_trends
    question: 各顧客の財務指標の推移を教えてください
    sql: "SELECT c.CUSTOMER_NAME, fs.FISCAL_YEAR_END, fs.REVENUE, fs.OPERATING_PROFIT, fs.NET_INCOME, fs.EQUITY_RATIO, fs.CURRENT_RATIO, fs.DEBT_EQUITY_RATIO FROM FINANCIAL_STATEMENT AS fs JOIN CUSTOMER AS c ON fs.CUSTOMER_ID = c.CUSTOMER_ID ORDER BY c.CUSTOMER_NAME, fs.FISCAL_YEAR_END"
    verified_at: 1774320823
    verified_by: Semantic Model Generator
  - name: portfolio_by_industry
    question: 業種別の融資残高と件数を教えてください
    sql: "SELECT c.INDUSTRY_NAME, COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMER_COUNT, COUNT(l.LOAN_ID) AS LOAN_COUNT, SUM(l.OUTSTANDING_BALANCE) AS TOTAL_BALANCE, AVG(l.INTEREST_RATE) AS AVG_RATE FROM CUSTOMER AS c JOIN LOAN AS l ON c.CUSTOMER_ID = l.CUSTOMER_ID WHERE l.RECORD_DATE = '2025-01-31' GROUP BY c.INDUSTRY_NAME ORDER BY TOTAL_BALANCE DESC"
    verified_at: 1774320823
    verified_by: Semantic Model Generator
  - name: collateral_coverage
    question: 担保付融資の担保カバー率を教えてください
    sql: "SELECT c.CUSTOMER_NAME, l.LOAN_PURPOSE, l.OUTSTANDING_BALANCE, co.COLLATERAL_TYPE, co.APPRAISED_VALUE, co.SECURED_VALUE, ROUND(co.SECURED_VALUE / NULLIF(l.OUTSTANDING_BALANCE, 0) * 100, 1) AS COVER_RATE FROM LOAN AS l JOIN CUSTOMER AS c ON l.CUSTOMER_ID = c.CUSTOMER_ID JOIN COLLATERAL AS co ON l.LOAN_ID = co.LOAN_ID WHERE l.RECORD_DATE = '2025-01-31' ORDER BY COVER_RATE ASC"
    verified_at: 1774320823
    verified_by: Semantic Model Generator
$$,
  FALSE
);


-- =========================================================
-- Step 2: 作成確認
-- =========================================================

SHOW SEMANTIC VIEWS IN SCHEMA CREDIT_MGMT_DB.ANALYTICS;


-- =========================================================
-- 03_sv_setup.sql 完了
-- =========================================================
--
-- 作成されたオブジェクト:
--   [CREDIT_MGMT_DB.ANALYTICS]
--     - CREDIT_ANALYSIS_SV（Semantic View）
--       7テーブル / 4リレーションシップ / 5 VQR
--
-- 次のステップ:
--   → 04_sproc_setup.sql（Stored Procedure）
--
-- =========================================================
