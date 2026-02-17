-- =====================================================
-- SNOWCREDIT 環境構築
-- =====================================================

-- =============================================================================
-- 1. ロール・ウェアハウス設定
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS SNOW_CREDIT_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'SnowCredit デモ用ウェアハウス';

USE WAREHOUSE SNOW_CREDIT_WH;

-- =============================================================================
-- 2. データベース・スキーマ作成
-- =============================================================================
CREATE DATABASE IF NOT EXISTS SNOW_CREDIT;
CREATE SCHEMA IF NOT EXISTS SNOW_CREDIT.DATA;
CREATE SCHEMA IF NOT EXISTS SNOW_CREDIT.AI;

USE DATABASE SNOW_CREDIT;
USE SCHEMA DATA;

-- =============================================================================
-- 3. テーブル作成（DDL）
-- =============================================================================

-- 2.1 DIM_CUSTOMER（顧客マスタ）
CREATE OR REPLACE TABLE DIM_CUSTOMER (
    CUSTOMER_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    CUSTOMER_NUMBER VARCHAR(16777216) NOT NULL,
    CARD_NUMBER VARCHAR(16777216) NOT NULL,
    CUSTOMER_NAME VARCHAR(16777216) NOT NULL,
    CUSTOMER_NAME_KANA VARCHAR(16777216),
    BIRTH_DATE DATE,
    GENDER VARCHAR(16777216),
    POSTAL_CODE VARCHAR(16777216),
    ADDRESS VARCHAR(16777216),
    PHONE_NUMBER VARCHAR(16777216),
    EMAIL_ADDRESS VARCHAR(16777216),
    OCCUPATION VARCHAR(16777216),
    ANNUAL_INCOME NUMBER(12,0),
    CARD_TYPE VARCHAR(16777216) NOT NULL,
    ANNUAL_FEE NUMBER(8,0) DEFAULT 0,
    CREDIT_LIMIT NUMBER(10,0),
    ISSUE_DATE DATE NOT NULL,
    EXPIRY_DATE DATE NOT NULL,
    JOIN_DATE DATE NOT NULL,
    LAST_UPDATED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE
) COMMENT='顧客マスタ：人口統計情報や財務情報を含む顧客情報';

-- 2.2 DIM_MERCHANT（加盟店マスタ）
CREATE OR REPLACE TABLE DIM_MERCHANT (
    MERCHANT_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    MERCHANT_NUMBER VARCHAR(16777216) NOT NULL,
    MERCHANT_NAME VARCHAR(16777216) NOT NULL,
    INDUSTRY_CODE VARCHAR(16777216),
    INDUSTRY_NAME VARCHAR(16777216),
    COUNTRY_NAME VARCHAR(16777216),
    PREFECTURE VARCHAR(16777216),
    CITY VARCHAR(16777216),
    ONLINE_FLAG BOOLEAN DEFAULT FALSE,
    CONTRACT_DATE DATE NOT NULL,
    LAST_UPDATED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
) COMMENT='加盟店マスタ：加盟店の識別情報と分類情報';

-- 2.3 DIM_CAMPAIGN（キャンペーンマスタ）
CREATE OR REPLACE TABLE DIM_CAMPAIGN (
    CAMPAIGN_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    CAMPAIGN_CODE VARCHAR(16777216) NOT NULL,
    CAMPAIGN_NAME VARCHAR(16777216) NOT NULL,
    CAMPAIGN_TYPE VARCHAR(16777216),
    TARGET_INDUSTRY_CODE VARCHAR(16777216),
    ADDITIONAL_REWARD_RATE NUMBER(5,4) DEFAULT 0,
    START_DATE DATE NOT NULL,
    END_DATE DATE NOT NULL,
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    LAST_UPDATED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
) COMMENT='キャンペーンマスタ：マーケティングキャンペーン情報';

-- 2.4 FACT_TRANSACTION（取引ファクト）
CREATE OR REPLACE TABLE FACT_TRANSACTION (
    TRANSACTION_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    TRANSACTION_NUMBER VARCHAR(16777216) NOT NULL,
    CUSTOMER_KEY NUMBER(38,0),
    MERCHANT_KEY NUMBER(38,0),
    DATE_KEY NUMBER(38,0),
    CAMPAIGN_KEY NUMBER(38,0),
    TRANSACTION_DATETIME TIMESTAMP_NTZ(9) NOT NULL,
    TRANSACTION_AMOUNT NUMBER(12,2) NOT NULL,
    CURRENCY_CODE VARCHAR(16777216) DEFAULT 'JPY',
    TRANSACTION_TYPE VARCHAR(16777216) NOT NULL,
    APPROVAL_NUMBER VARCHAR(16777216),
    SETTLEMENT_STATUS VARCHAR(16777216) DEFAULT '確定',
    EARNED_POINTS NUMBER(10,0) DEFAULT 0,
    FEE_RATE NUMBER(5,4),
    FEE_AMOUNT NUMBER(10,2),
    OVERSEAS_FLAG BOOLEAN DEFAULT FALSE,
    INSTALLMENT_COUNT NUMBER(2,0) DEFAULT 1,
    BONUS_TYPE VARCHAR(16777216),
    CREATED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
) COMMENT='取引ファクト：金融取引の記録';

-- 2.5 OPERATION_DOCUMENT（運用ドキュメント）
CREATE OR REPLACE TABLE OPERATION_DOCUMENT (
    DOCUMENT_ID VARCHAR(16777216),
    TITLE VARCHAR(16777216),
    CONTENT VARCHAR(16777216),
    DOCUMENT_TYPE VARCHAR(16777216),
    DEPARTMENT VARCHAR(16777216),
    CREATED_AT TIMESTAMP_NTZ(9),
    UPDATED_AT TIMESTAMP_NTZ(9),
    VERSION NUMBER(38,0)
) COMMENT='運用ドキュメント：組織内で作成された文書';

ALTER TABLE OPERATION_DOCUMENT SET CHANGE_TRACKING = TRUE;

-- =============================================================================
-- 4. サンプルデータ投入
-- =============================================================================

-- 3.1 DIM_MERCHANT（10件）
INSERT INTO DIM_MERCHANT (MERCHANT_NUMBER, MERCHANT_NAME, INDUSTRY_CODE, INDUSTRY_NAME, COUNTRY_NAME, PREFECTURE, CITY, ONLINE_FLAG, CONTRACT_DATE)
VALUES
('MC001', 'イオンモール東京', 'RETAIL', '小売業', '日本', '東京都', '品川区', FALSE, '2020-01-15'),
('MC002', 'Amazon Japan', 'EC', 'Eコマース', '日本', '東京都', '目黒区', TRUE, '2019-06-01'),
('MC003', 'セブンイレブン新宿店', 'CVS', 'コンビニエンスストア', '日本', '東京都', '新宿区', FALSE, '2021-03-20'),
('MC004', 'スターバックス渋谷', 'CAFE', '飲食業', '日本', '東京都', '渋谷区', FALSE, '2020-07-10'),
('MC005', 'ユニクロ銀座', 'APPAREL', 'アパレル', '日本', '東京都', '中央区', FALSE, '2019-11-25'),
('MC006', '楽天市場', 'EC', 'Eコマース', '日本', '東京都', '世田谷区', TRUE, '2018-04-01'),
('MC007', 'ビックカメラ池袋', 'ELECTRONICS', '家電量販', '日本', '東京都', '豊島区', FALSE, '2020-09-15'),
('MC008', 'マクドナルド秋葉原', 'FASTFOOD', '飲食業', '日本', '東京都', '千代田区', FALSE, '2021-01-05'),
('MC009', 'JAL国際線', 'AIRLINE', '航空', '日本', '東京都', '港区', TRUE, '2017-08-20'),
('MC010', 'ドン・キホーテ新宿', 'DISCOUNT', 'ディスカウントストア', '日本', '東京都', '新宿区', FALSE, '2022-02-28');

-- 3.2 DIM_CAMPAIGN（5件）
INSERT INTO DIM_CAMPAIGN (CAMPAIGN_CODE, CAMPAIGN_NAME, CAMPAIGN_TYPE, TARGET_INDUSTRY_CODE, ADDITIONAL_REWARD_RATE, START_DATE, END_DATE, ACTIVE_FLAG)
VALUES
('CP001', '夏のポイント2倍キャンペーン', 'POINT_BOOST', NULL, 0.01, '2025-07-01', '2025-08-31', TRUE),
('CP002', 'Eコマース限定5%還元', 'CASHBACK', 'EC', 0.05, '2025-01-01', '2025-12-31', TRUE),
('CP003', '飲食店利用ボーナス', 'BONUS', 'CAFE', 0.02, '2025-04-01', '2025-06-30', FALSE),
('CP004', '新規入会特典', 'WELCOME', NULL, 0.03, '2025-01-01', '2025-03-31', FALSE),
('CP005', '年末年始スペシャル', 'SEASONAL', NULL, 0.02, '2025-12-01', '2026-01-15', TRUE);

-- 3.3 DIM_CUSTOMER（100件）
INSERT INTO DIM_CUSTOMER (CUSTOMER_NUMBER, CARD_NUMBER, CUSTOMER_NAME, CUSTOMER_NAME_KANA, BIRTH_DATE, GENDER, POSTAL_CODE, ADDRESS, PHONE_NUMBER, EMAIL_ADDRESS, OCCUPATION, ANNUAL_INCOME, CARD_TYPE, ANNUAL_FEE, CREDIT_LIMIT, ISSUE_DATE, EXPIRY_DATE, JOIN_DATE, ACTIVE_FLAG)
SELECT 
    'M' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    '357' || UNIFORM(1000000000000, 9999999999999, RANDOM())::VARCHAR,
    ARRAY_CONSTRUCT('佐藤', '鈴木', '高橋', '田中', '渡辺', '伊藤', '山本', '中村', '小林', '加藤')[UNIFORM(0, 9, RANDOM())::INT] || ' ' ||
    CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 
         THEN ARRAY_CONSTRUCT('太郎', '一郎', '健太', '大輔', '翔太', '拓也', '直樹', '哲也', '雄一', '浩二')[UNIFORM(0, 9, RANDOM())::INT]
         ELSE ARRAY_CONSTRUCT('花子', '美咲', '陽子', '恵子', '由美', '裕子', '真理', '久美子', '明美', '幸子')[UNIFORM(0, 9, RANDOM())::INT]
    END,
    'カナシメイ',
    DATEADD(DAY, -UNIFORM(9000, 23000, RANDOM()), CURRENT_DATE()),
    CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 THEN '男性' ELSE '女性' END,
    UNIFORM(100, 999, RANDOM())::VARCHAR || '-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR,
    ARRAY_CONSTRUCT('東京都', '神奈川県', '千葉県', '埼玉県', '大阪府', '愛知県', '福岡県', '北海道', '宮城県', '広島県')[UNIFORM(0, 9, RANDOM())::INT],
    '0' || UNIFORM(3, 9, RANDOM())::VARCHAR || '0-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR || '-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR,
    'user' || SEQ4()::VARCHAR || '@example.com',
    ARRAY_CONSTRUCT('会社員', '公務員', '自営業', '会社役員', '医師', '弁護士', '教師', 'エンジニア', '看護師', '主婦')[UNIFORM(0, 9, RANDOM())::INT],
    CASE 
        WHEN MOD(SEQ4(), 100) < 8 THEN UNIFORM(2000000, 2500000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 20 THEN UNIFORM(2500000, 3000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 38 THEN UNIFORM(3000000, 4000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 54 THEN UNIFORM(4000000, 5000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 68 THEN UNIFORM(5000000, 6000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 80 THEN UNIFORM(6000000, 7000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 90 THEN UNIFORM(7000000, 9000000, RANDOM())
        WHEN MOD(SEQ4(), 100) < 97 THEN UNIFORM(9000000, 12000000, RANDOM())
        ELSE UNIFORM(12000000, 18000000, RANDOM())
    END,
    CASE 
        WHEN MOD(SEQ4(), 10) < 6 THEN '一般'
        WHEN MOD(SEQ4(), 10) < 9 THEN 'ゴールド'
        ELSE 'プラチナ'
    END,
    CASE 
        WHEN MOD(SEQ4(), 10) < 6 THEN 0
        WHEN MOD(SEQ4(), 10) < 9 THEN 11000
        ELSE 33000
    END,
    CASE 
        WHEN MOD(SEQ4(), 10) < 6 THEN 500000
        WHEN MOD(SEQ4(), 10) < 9 THEN 1000000
        ELSE 3000000
    END,
    DATEADD(DAY, UNIFORM(0, 1800, RANDOM()), '2020-01-01'::DATE),
    DATEADD(YEAR, 5, DATEADD(DAY, UNIFORM(0, 1800, RANDOM()), '2020-01-01'::DATE)),
    DATEADD(DAY, UNIFORM(0, 1800, RANDOM()), '2020-01-01'::DATE),
    TRUE
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- 3.4 FACT_TRANSACTION（500件）
INSERT INTO FACT_TRANSACTION (TRANSACTION_NUMBER, CUSTOMER_KEY, MERCHANT_KEY, DATE_KEY, CAMPAIGN_KEY, TRANSACTION_DATETIME, TRANSACTION_AMOUNT, CURRENCY_CODE, TRANSACTION_TYPE, APPROVAL_NUMBER, SETTLEMENT_STATUS, EARNED_POINTS, FEE_RATE, FEE_AMOUNT, OVERSEAS_FLAG, INSTALLMENT_COUNT, BONUS_TYPE)
SELECT 
    'T' || LPAD(SEQ4()::VARCHAR, 10, '0'),
    UNIFORM(1, 100, RANDOM()),
    UNIFORM(1, 10, RANDOM()),
    TO_NUMBER(TO_CHAR(tx_dt, 'YYYYMMDD')),
    CASE WHEN UNIFORM(0, 5, RANDOM()) < 5 THEN UNIFORM(1, 5, RANDOM()) ELSE NULL END,
    tx_dt,
    tx_amt,
    'JPY',
    CASE 
        WHEN UNIFORM(0, 99, RANDOM()) < 95 THEN '売上'
        WHEN UNIFORM(0, 99, RANDOM()) < 98 THEN '返品'
        ELSE '取消'
    END,
    'AUTH' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    '確定',
    FLOOR(tx_amt * UNIFORM(0.005, 0.03, RANDOM())),
    fee_rt,
    ROUND(tx_amt * fee_rt, 2),
    UNIFORM(0, 99, RANDOM()) < 5,
    ARRAY_CONSTRUCT(1, 1, 1, 1, 1, 1, 1, 3, 6, 12)[UNIFORM(0, 9, RANDOM())::INT],
    CASE WHEN UNIFORM(0, 9, RANDOM()) > 7 THEN ARRAY_CONSTRUCT('夏季', '冬季')[UNIFORM(0, 1, RANDOM())::INT] ELSE NULL END
FROM (
    SELECT 
        SEQ4(),
        DATEADD(MINUTE, UNIFORM(0, 525600, RANDOM()), '2025-01-01 08:00:00'::TIMESTAMP) AS tx_dt,
        ROUND(UNIFORM(500, 150000, RANDOM()), 2) AS tx_amt,
        ROUND(UNIFORM(0.02, 0.05, RANDOM()), 4) AS fee_rt
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
);

-- 3.5 OPERATION_DOCUMENT（18件）
INSERT INTO OPERATION_DOCUMENT (DOCUMENT_ID, TITLE, CONTENT, DOCUMENT_TYPE, DEPARTMENT, CREATED_AT, UPDATED_AT, VERSION)
VALUES
('DOC001', 'カード発行業務マニュアル', 'カード発行の手順について記載。申込受付から審査、カード製造、発送までの一連の流れを説明します。審査基準には年収、勤続年数、信用情報が含まれます。', 'マニュアル', '発行部門', '2024-01-15 09:00:00', '2024-06-01 14:30:00', 3),
('DOC002', '不正検知システム運用手順', '不正取引検知システムの日次運用手順。アラート確認、調査手順、顧客連絡方法について記載。異常パターンの判定基準も含む。', 'マニュアル', 'セキュリティ部門', '2024-02-01 10:00:00', '2024-07-15 11:00:00', 2),
('DOC003', 'コールセンター対応FAQ', 'お客様からよくある質問と回答集。利用限度額変更、ポイント照会、紛失届、住所変更などの対応方法をまとめています。', 'FAQ', 'カスタマーサポート', '2024-03-01 08:30:00', '2024-08-20 16:45:00', 5),
('DOC004', 'ポイントプログラム規約', 'クレジットカードポイントプログラムの利用規約。ポイント付与率、有効期限、交換方法、特典内容について詳細に記載。', '規約', '企画部門', '2024-01-01 00:00:00', '2024-04-01 00:00:00', 2),
('DOC005', '加盟店審査基準', '新規加盟店の審査基準と手続き。業種別リスク評価、必要書類、審査期間、手数料率決定ロジックを説明。', 'ガイドライン', '加盟店管理部', '2024-04-15 13:00:00', '2024-09-01 10:30:00', 4),
('DOC006', '海外利用時の注意事項', '海外でのカード利用に関する注意事項。為替レート適用タイミング、海外利用手数料、緊急連絡先、不正利用対策について記載。', 'ガイドライン', 'カスタマーサポート', '2024-05-01 11:00:00', '2024-10-15 09:00:00', 2),
('DOC007', '与信管理ポリシー', '与信枠の設定・変更に関するポリシー。初期与信枠の決定方法、増枠審査基準、減枠条件、延滞時の対応について記載。', 'ポリシー', 'リスク管理部', '2024-02-15 14:00:00', '2024-07-01 15:30:00', 3),
('DOC008', '年会費請求業務手順', '年会費の請求・入金確認・督促に関する業務手順。請求タイミング、入金確認方法、未入金時のフォロー手順を説明。', 'マニュアル', '経理部門', '2024-03-15 09:30:00', '2024-08-01 11:00:00', 2),
('DOC009', 'キャンペーン企画ガイドライン', 'ポイントキャンペーンの企画・実施に関するガイドライン。対象条件設定、ポイント計算ロジック、告知方法、効果測定について記載。', 'ガイドライン', 'マーケティング部', '2024-06-01 10:00:00', '2024-11-01 14:00:00', 3),
('DOC010', '個人情報保護対応マニュアル', '個人情報の取り扱いに関するマニュアル。情報収集、保管、利用、廃棄の各フェーズでの対応方法と注意点を記載。', 'マニュアル', 'コンプライアンス部', '2024-01-10 08:00:00', '2024-05-20 16:00:00', 4),
('DOC011', 'システム障害対応手順', 'システム障害発生時の対応手順。初動対応、エスカレーション、復旧手順、顧客への影響確認と連絡方法について記載。', 'マニュアル', 'IT部門', '2024-04-01 09:00:00', '2024-09-15 13:00:00', 3),
('DOC012', '分割払い・リボ払い説明資料', '分割払いとリボ払いの仕組み説明資料。手数料計算方法、支払いシミュレーション、注意事項をお客様向けに分かりやすく解説。', '説明資料', 'カスタマーサポート', '2024-02-20 11:30:00', '2024-06-15 10:00:00', 2),
('DOC013', '法人カード運用規定', '法人カードの発行・管理に関する規定。申込条件、利用限度額設定、経費精算連携、管理者権限について記載。', '規定', '法人営業部', '2024-05-15 14:00:00', '2024-10-01 11:30:00', 2),
('DOC014', 'ETCカード発行手順', 'ETCカードの申込受付から発行までの手順。申込条件、審査基準、発行期間、車載器登録方法について記載。', 'マニュアル', '発行部門', '2024-03-10 10:00:00', '2024-07-20 09:30:00', 2),
('DOC015', 'カード紛失・盗難対応マニュアル', 'カードの紛失・盗難発生時の対応手順。利用停止処理、不正利用調査、再発行手続き、保険適用について記載。', 'マニュアル', 'セキュリティ部門', '2024-01-20 13:00:00', '2024-04-10 15:00:00', 3),
('DOC016', 'ゴールドカード特典ガイド', 'ゴールドカード会員向け特典の詳細ガイド。空港ラウンジ、旅行保険、コンシェルジュサービス、ポイント優遇について記載。', 'ガイド', 'マーケティング部', '2024-06-15 11:00:00', '2024-11-15 10:00:00', 2),
('DOC017', '請求書発行業務マニュアル', '月次請求書の発行業務手順。締め日処理、請求額計算、発行・送付方法、問い合わせ対応について記載。', 'マニュアル', '経理部門', '2024-04-20 09:00:00', '2024-08-10 14:30:00', 2),
('DOC018', 'プラチナカード審査基準', 'プラチナカードへのアップグレード審査基準。収入要件、利用実績、審査プロセス、特典内容について記載。', 'ガイドライン', '発行部門', '2024-07-01 10:00:00', '2024-12-01 11:00:00', 1);

-- =============================================================================
-- 5. Semantic View 作成（YAML経由 - Verified Query付き）
-- =============================================================================

-- 4.1 SV_CUSTOMER_TRANSACTION（統合ビュー with Verified Queries）
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'SNOW_CREDIT.AI',
  $$
name: SV_CUSTOMER_TRANSACTION
description: |
  顧客情報と取引情報を統合した分析用セマンティックビュー。
  顧客別の取引分析、カード種別ごとの利用傾向分析が可能です。

tables:
  - name: CUSTOMER
    description: クレジットカード会員の基本情報
    base_table:
      database: SNOW_CREDIT
      schema: DATA
      table: DIM_CUSTOMER
    synonyms:
      - 顧客
      - カード会員
      - 会員
    primary_key:
      columns:
        - CUSTOMER_KEY
    dimensions:
      - name: CUSTOMER_KEY
        expr: CUSTOMER_KEY
        data_type: NUMBER(38,0)
        description: 顧客サロゲートキー
      - name: CUSTOMER_NUMBER
        expr: CUSTOMER_NUMBER
        data_type: VARCHAR
        description: 顧客番号（会員番号）
        synonyms:
          - 会員ID
          - 会員番号
      - name: CUSTOMER_NAME
        expr: CUSTOMER_NAME
        data_type: VARCHAR
        description: 顧客氏名
        synonyms:
          - 氏名
          - 名前
      - name: GENDER
        expr: GENDER
        data_type: VARCHAR
        description: 性別（男性/女性）
        synonyms:
          - 男女
      - name: ADDRESS
        expr: ADDRESS
        data_type: VARCHAR
        description: 住所（都道府県）
        synonyms:
          - 都道府県
          - 居住地
      - name: OCCUPATION
        expr: OCCUPATION
        data_type: VARCHAR
        description: 職業
        synonyms:
          - 仕事
      - name: CARD_TYPE
        expr: CARD_TYPE
        data_type: VARCHAR
        description: カード種別（一般/ゴールド/プラチナ）
        synonyms:
          - カードグレード
          - カードランク
      - name: ACTIVE_FLAG
        expr: ACTIVE_FLAG
        data_type: BOOLEAN
        description: 有効フラグ
    facts:
      - name: ANNUAL_INCOME
        expr: ANNUAL_INCOME
        data_type: NUMBER(12,0)
        description: 年収（円）
        synonyms:
          - 収入
      - name: CREDIT_LIMIT
        expr: CREDIT_LIMIT
        data_type: NUMBER(10,0)
        description: 利用限度額（円）
        synonyms:
          - 与信枠
    metrics:
      - name: CUSTOMER_COUNT
        expr: COUNT(CUSTOMER_KEY)
        description: 顧客数
        synonyms:
          - 会員数
      - name: AVG_ANNUAL_INCOME
        expr: AVG(ANNUAL_INCOME)
        description: 平均年収（円）

  - name: TX
    description: クレジットカード取引データ
    base_table:
      database: SNOW_CREDIT
      schema: DATA
      table: FACT_TRANSACTION
    synonyms:
      - 取引
      - 利用明細
      - 決済
    primary_key:
      columns:
        - TRANSACTION_KEY
    dimensions:
      - name: TRANSACTION_KEY
        expr: TRANSACTION_KEY
        data_type: NUMBER(38,0)
        description: 取引サロゲートキー
      - name: TRANSACTION_NUMBER
        expr: TRANSACTION_NUMBER
        data_type: VARCHAR
        description: 取引番号
      - name: CUSTOMER_KEY
        expr: CUSTOMER_KEY
        data_type: NUMBER(38,0)
        description: 顧客キー（FK）
      - name: MERCHANT_KEY
        expr: MERCHANT_KEY
        data_type: NUMBER(38,0)
        description: 加盟店キー（FK）
      - name: TRANSACTION_DATETIME
        expr: TRANSACTION_DATETIME
        data_type: TIMESTAMP_NTZ
        description: 取引日時
        synonyms:
          - 利用日
          - 決済日時
      - name: TRANSACTION_TYPE
        expr: TRANSACTION_TYPE
        data_type: VARCHAR
        description: 取引種別（売上/返品/取消）
      - name: OVERSEAS_FLAG
        expr: OVERSEAS_FLAG
        data_type: BOOLEAN
        description: 海外利用フラグ
    facts:
      - name: TRANSACTION_AMOUNT
        expr: TRANSACTION_AMOUNT
        data_type: NUMBER(12,2)
        description: 取引金額（円）
        synonyms:
          - 利用金額
          - 決済金額
      - name: EARNED_POINTS
        expr: EARNED_POINTS
        data_type: NUMBER(10,0)
        description: 獲得ポイント
        synonyms:
          - 付与ポイント
    metrics:
      - name: TOTAL_TRANSACTION_AMOUNT
        expr: SUM(TRANSACTION_AMOUNT)
        description: 合計取引金額
        synonyms:
          - 総売上
      - name: TRANSACTION_COUNT
        expr: COUNT(TRANSACTION_KEY)
        description: 取引件数
      - name: AVG_TRANSACTION_AMOUNT
        expr: AVG(TRANSACTION_AMOUNT)
        description: 平均取引金額
      - name: TOTAL_EARNED_POINTS
        expr: SUM(EARNED_POINTS)
        description: 合計獲得ポイント

  - name: MERCHANT
    description: 加盟店マスタ
    base_table:
      database: SNOW_CREDIT
      schema: DATA
      table: DIM_MERCHANT
    synonyms:
      - 加盟店
      - 店舗
    primary_key:
      columns:
        - MERCHANT_KEY
    dimensions:
      - name: MERCHANT_KEY
        expr: MERCHANT_KEY
        data_type: NUMBER(38,0)
        description: 加盟店サロゲートキー
      - name: MERCHANT_NAME
        expr: MERCHANT_NAME
        data_type: VARCHAR
        description: 加盟店名
      - name: INDUSTRY_NAME
        expr: INDUSTRY_NAME
        data_type: VARCHAR
        description: 業種名

relationships:
  - name: TX_TO_CUSTOMER
    left_table: TX
    right_table: CUSTOMER
    relationship_columns:
      - left_column: CUSTOMER_KEY
        right_column: CUSTOMER_KEY
    relationship_type: many_to_one
  - name: TX_TO_MERCHANT
    left_table: TX
    right_table: MERCHANT
    relationship_columns:
      - left_column: MERCHANT_KEY
        right_column: MERCHANT_KEY
    relationship_type: many_to_one

verified_queries:
  - name: カード種別ごとの顧客数と平均年収
    question: カード種別ごとに顧客数と平均年収を教えて
    use_as_onboarding_question: true
    sql: |
      SELECT
        __customer.card_type,
        COUNT(__customer.customer_key) AS customer_count,
        ROUND(AVG(__customer.annual_income), 0) AS avg_annual_income
      FROM __customer
      GROUP BY __customer.card_type
      ORDER BY customer_count DESC

  - name: 月別取引金額の推移
    question: 月別の取引金額と取引件数の推移を見せて
    use_as_onboarding_question: true
    sql: |
      SELECT
        DATE_TRUNC('MONTH', __tx.transaction_datetime) AS transaction_month,
        SUM(__tx.transaction_amount) AS total_amount,
        COUNT(__tx.transaction_key) AS transaction_count
      FROM __tx
      GROUP BY DATE_TRUNC('MONTH', __tx.transaction_datetime)
      ORDER BY transaction_month

  - name: 性別とカード種別のクロス分析
    question: 性別とカード種別ごとの顧客数を集計して
    use_as_onboarding_question: true
    sql: |
      SELECT
        __customer.gender,
        __customer.card_type,
        COUNT(__customer.customer_key) AS customer_count
      FROM __customer
      GROUP BY __customer.gender, __customer.card_type
      ORDER BY __customer.gender, __customer.card_type

  - name: 取引金額上位の顧客
    question: 取引金額が多い上位10名の顧客を教えて
    use_as_onboarding_question: false
    sql: |
      SELECT
        __customer.customer_name,
        __customer.card_type,
        SUM(__tx.transaction_amount) AS total_amount,
        COUNT(__tx.transaction_key) AS transaction_count
      FROM __tx
      INNER JOIN __customer ON __tx.customer_key = __customer.customer_key
      GROUP BY __customer.customer_name, __customer.card_type
      ORDER BY total_amount DESC
      LIMIT 10

  - name: 業種別取引分析
    question: 業種別の取引金額と取引件数を集計して
    use_as_onboarding_question: false
    sql: |
      SELECT
        __merchant.industry_name,
        SUM(__tx.transaction_amount) AS total_amount,
        COUNT(__tx.transaction_key) AS transaction_count,
        ROUND(AVG(__tx.transaction_amount), 0) AS avg_amount
      FROM __tx
      INNER JOIN __merchant ON __tx.merchant_key = __merchant.merchant_key
      GROUP BY __merchant.industry_name
      ORDER BY total_amount DESC
$$
);

-- =============================================================================
-- 6. Cortex Search Service 作成
-- =============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE SNOW_CREDIT.AI.OPERATION_DOCUMENTS_CSS
    ON CONTENT
    ATTRIBUTES TITLE, DOCUMENT_TYPE, DEPARTMENT
    WAREHOUSE = SNOW_CREDIT_WH
    TARGET_LAG = '1 hour'
    COMMENT = '業務マニュアル・FAQ・規約などの運用ドキュメント検索サービス'
    AS (
        SELECT
            DOCUMENT_ID,
            TITLE,
            CONTENT,
            DOCUMENT_TYPE,
            DEPARTMENT,
            VERSION
        FROM SNOW_CREDIT.DATA.OPERATION_DOCUMENT
    );

-- =============================================================================
-- 7. Cortex Agent 作成
-- =============================================================================
CREATE OR REPLACE AGENT SNOW_CREDIT.AI.CREDIT_CARD_AGENT
  COMMENT = 'このエージェントはクレジットカード業界における、お客さま情報・加盟店情報・キャンペーン情報・取引明細について熟知したエージェントです。業務マニュアルの情報も把握しており回答が可能です'
  PROFILE = '{"display_name": "Credit Card Agent"}'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-4-sonnet

instructions:
  response: |
    1. 質問に対する回答、およびThinking Stepsは必ず日本語で行うこと
    2. 回答の構成：
       - 最初に結論または要約を提示
       - 必要に応じて詳細や根拠を説明
       - データに基づく回答の場合は、数値や期間を明確に記載
    3. データ分析の回答時：
       - 件数、金額、割合などの数値は適切な単位で表示
       - 比較や傾向がある場合は明確に説明
       - 件数、金額、割合などの数値は適切なグラフで可視化することが望ましい
    4. 免責事項：
       - 回答の末尾に必ず以下の免責事項を記載すること
       - "【免責事項】本回答はSnowflake Intelligenceによるデモンストレーション目的で生成されたものです。実際の金融アドバイス、投資判断、または業務上の意思決定に使用しないでください。SnowCreditは架空のクレジットカード会社であり、表示されるデータはすべてサンプルデータです。"
  orchestration: |
    1. ユーザーからの質問を受け取り、質問の意図を分析する
    2. 質問の内容に応じて、適切なツールを選択：
       - 構造化データ（顧客情報、取引データ、加盟店情報など）に関する質問 → Analyst
       - 業務マニュアル、FAQ、規約に関する質問 → DocumentSearch
    3. ツールの使い分け基準：
       - 「〇〇の件数」「合計金額」「平均」など数値を求める質問 → Analyst
       - 「手順」「方法」「規約」「ルール」に関する質問 → DocumentSearch
       - 複合的な質問の場合は、必要に応じて複数のツールを使用
  sample_questions:
    - question: "カード種別ごとに顧客数と平均年収を教えてください"
      answer: "お客様分析をするために、顧客データからカード種別ごとに顧客数と平均年収を調べてください"
    - question: "では、次は業種別の取引金額と取引件数を集計してもらえますか"
      answer: "顧客データから、業種別の取引金額と取引件数を集計します。"
    - question: "カード紛失時の対応手順を教えてください"
      answer: "業務マニュアルから、カード紛失時の対応手順をご案内します。"
    - question: "海外利用時の注意事項は何ですか"
      answer: "利用規約から、海外利用に関する注意事項をお伝えします。"
    - question: "最近高額取引をしている顧客を確認し、利用限度額の変更手続きについても教えてください"
      answer: "取引データから高額利用の顧客を抽出し、与信管理ポリシーから利用限度額の変更手続きをご案内します。"

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Analyst
      description: "顧客情報、取引データ、加盟店情報、キャンペーン情報などの構造化データに関する質問に回答します"

  - tool_spec:
      type: cortex_search
      name: DocumentSearch
      description: "業務マニュアル、FAQ、利用規約、ガイドラインなどのドキュメントを検索します"

tool_resources:
  Analyst:
    semantic_view: "SNOW_CREDIT.AI.SV_CUSTOMER_TRANSACTION"
  DocumentSearch:
    name: "SNOW_CREDIT.AI.OPERATION_DOCUMENTS_CSS"
    max_results: "5"
$$;

-- =============================================================================
-- 8. 検証
-- =============================================================================
SELECT 'DIM_CUSTOMER' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOW_CREDIT.DATA.DIM_CUSTOMER
UNION ALL SELECT 'DIM_MERCHANT', COUNT(*) FROM SNOW_CREDIT.DATA.DIM_MERCHANT
UNION ALL SELECT 'DIM_CAMPAIGN', COUNT(*) FROM SNOW_CREDIT.DATA.DIM_CAMPAIGN
UNION ALL SELECT 'FACT_TRANSACTION', COUNT(*) FROM SNOW_CREDIT.DATA.FACT_TRANSACTION
UNION ALL SELECT 'OPERATION_DOCUMENT', COUNT(*) FROM SNOW_CREDIT.DATA.OPERATION_DOCUMENT;

SHOW SEMANTIC VIEWS IN SCHEMA SNOW_CREDIT.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOW_CREDIT.AI;
SHOW AGENTS IN SCHEMA SNOW_CREDIT.AI;

-- =============================================================================
-- 9. 権限付与（必要に応じてコメント解除）
-- =============================================================================
-- SET TARGET_ROLE = 'DATA_ANALYST';
-- GRANT USAGE ON DATABASE SNOW_CREDIT TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON SCHEMA SNOW_CREDIT.DATA TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON SCHEMA SNOW_CREDIT.AI TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT SELECT ON ALL TABLES IN SCHEMA SNOW_CREDIT.DATA TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA SNOW_CREDIT.AI TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON CORTEX SEARCH SERVICE SNOW_CREDIT.AI.OPERATION_DOCUMENTS_CSS TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON AGENT SNOW_CREDIT.AI.CREDIT_CARD_AGENT TO ROLE IDENTIFIER($TARGET_ROLE);
