-- ============================================================
-- LIFE INSURANCE INTELLIGENCE AGENT - COMPLETE SETUP SCRIPT
-- ============================================================
-- このスクリプトは以下を自動セットアップします：
-- 1. データベース/スキーマ/ウェアハウスの作成
-- 2. テーブルの作成とサンプルデータの投入
-- 3. Cortex Search Serviceの作成
-- 4. Semantic View（2分割：営業向け/請求部門向け）の作成
-- 5. Cortex Agentの作成
-- ============================================================

-- ============================================================
-- STEP 1: 環境設定
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SF_INSURANCE_DB;
CREATE SCHEMA IF NOT EXISTS SF_INSURANCE_DB.DATA;
CREATE SCHEMA IF NOT EXISTS SF_INSURANCE_DB.SEMANTIC_VIEW;
CREATE SCHEMA IF NOT EXISTS SF_INSURANCE_DB.CORTEX_SEARCH;
CREATE SCHEMA IF NOT EXISTS SF_INSURANCE_DB.AGENTS;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
    WITH WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE;

USE DATABASE SF_INSURANCE_DB;
USE SCHEMA DATA;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- STEP 2: テーブルの作成
-- ============================================================

-- 保険商品マスタ
CREATE OR REPLACE TABLE INSURANCE_PRODUCTS (
    PRODUCT_ID VARCHAR(20) NOT NULL PRIMARY KEY,
    PRODUCT_NAME VARCHAR(100) NOT NULL,
    PRODUCT_CATEGORY VARCHAR(50),
    PRODUCT_TYPE VARCHAR(50),
    MIN_AGE NUMBER(3,0),
    MAX_AGE NUMBER(3,0),
    COVERAGE_AMOUNT_MIN NUMBER(12,0),
    COVERAGE_AMOUNT_MAX NUMBER(12,0),
    PREMIUM_CALCULATION_METHOD VARCHAR(100),
    DESCRIPTION VARCHAR(16777216),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 顧客マスタ
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID VARCHAR(20) NOT NULL PRIMARY KEY,
    CUSTOMER_NAME VARCHAR(100) NOT NULL,
    CUSTOMER_NAME_KANA VARCHAR(100),
    BIRTH_DATE DATE NOT NULL,
    AGE NUMBER(3,0),
    GENDER VARCHAR(10),
    MARITAL_STATUS VARCHAR(20),
    OCCUPATION VARCHAR(100),
    ANNUAL_INCOME NUMBER(12,0),
    POSTAL_CODE VARCHAR(10),
    PREFECTURE VARCHAR(20),
    CITY VARCHAR(50),
    ADDRESS VARCHAR(200),
    PHONE_NUMBER VARCHAR(20),
    EMAIL VARCHAR(100),
    REGISTRATION_DATE DATE DEFAULT CURRENT_DATE(),
    LAST_CONTACT_DATE DATE,
    CUSTOMER_SEGMENT VARCHAR(20),
    RISK_LEVEL VARCHAR(10),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 家族情報
CREATE OR REPLACE TABLE FAMILY_MEMBERS (
    FAMILY_ID VARCHAR(20) NOT NULL PRIMARY KEY,
    CUSTOMER_ID VARCHAR(20) NOT NULL,
    RELATIONSHIP VARCHAR(20),
    FAMILY_MEMBER_NAME VARCHAR(100),
    BIRTH_DATE DATE,
    AGE NUMBER(3,0),
    GENDER VARCHAR(10),
    OCCUPATION VARCHAR(100),
    IS_DEPENDENT BOOLEAN DEFAULT FALSE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 保険契約
CREATE OR REPLACE TABLE INSURANCE_CONTRACTS (
    CONTRACT_ID VARCHAR(20) NOT NULL PRIMARY KEY,
    CUSTOMER_ID VARCHAR(20) NOT NULL,
    PRODUCT_ID VARCHAR(20) NOT NULL,
    CONTRACT_DATE DATE NOT NULL,
    CONTRACT_STATUS VARCHAR(20),
    COVERAGE_AMOUNT NUMBER(12,0),
    MONTHLY_PREMIUM NUMBER(10,0),
    PAYMENT_METHOD VARCHAR(20),
    PAYMENT_FREQUENCY VARCHAR(20),
    BENEFICIARY_NAME VARCHAR(100),
    BENEFICIARY_RELATIONSHIP VARCHAR(50),
    POLICY_ANNIVERSARY_MONTH NUMBER(2,0),
    NEXT_RENEWAL_DATE DATE,
    AGENT_ID VARCHAR(20),
    SALES_CHANNEL VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 保険金請求履歴
CREATE OR REPLACE TABLE CLAIM_HISTORY (
    CLAIM_ID VARCHAR(20) NOT NULL PRIMARY KEY,
    CONTRACT_ID VARCHAR(20) NOT NULL,
    CUSTOMER_ID VARCHAR(20) NOT NULL,
    CLAIM_DATE DATE NOT NULL,
    CLAIM_TYPE VARCHAR(50),
    CLAIM_AMOUNT NUMBER(12,0),
    CLAIM_STATUS VARCHAR(20),
    CLAIM_REASON VARCHAR(16777216),
    PAYMENT_DATE DATE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 保険ドキュメント (Cortex Search用)
CREATE OR REPLACE TABLE INSURANCE_DOCUMENTS (
    DOCUMENT_ID VARCHAR(16777216),
    TITLE VARCHAR(16777216),
    CONTENT VARCHAR(16777216),
    DOCUMENT_TYPE VARCHAR(16777216),
    DEPARTMENT VARCHAR(16777216),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    VERSION NUMBER(38,1)
);

ALTER TABLE INSURANCE_DOCUMENTS SET CHANGE_TRACKING = TRUE;

-- ============================================================
-- STEP 3: サンプルデータの投入
-- ============================================================

-- 保険商品データ
INSERT INTO INSURANCE_PRODUCTS (PRODUCT_ID, PRODUCT_NAME, PRODUCT_CATEGORY, PRODUCT_TYPE, MIN_AGE, MAX_AGE, COVERAGE_AMOUNT_MIN, COVERAGE_AMOUNT_MAX, PREMIUM_CALCULATION_METHOD, DESCRIPTION, IS_ACTIVE) VALUES
('PROD001', '終身保険プレミアム', '生命保険', '終身保険', 20, 70, 1000000, 50000000, '年齢・性別・職業別', '一生涯の保障を提供する終身保険', TRUE),
('PROD002', '定期保険ファミリー', '生命保険', '定期保険', 18, 65, 500000, 30000000, '年齢・性別・職業別', '一定期間の保障を提供する定期保険', TRUE),
('PROD003', '医療保険総合', '医療保険', '総合医療保険', 18, 80, 5000, 20000, '年齢・性別・職業別', '入院・手術・通院を総合的に保障', TRUE),
('PROD004', 'がん保険プラス', 'がん保険', 'がん専用保険', 20, 75, 10000, 50000, '年齢・性別・職業別', 'がんに特化した保険商品', TRUE),
('PROD005', '学資保険みらい', '学資保険', '教育資金保険', 18, 50, 500000, 5000000, '子どもの年齢・親の年齢', '子どもの教育資金を準備する保険', TRUE),
('PROD006', '個人年金保険ゆとり', '個人年金保険', '確定年金', 20, 60, 1000000, 20000000, '年齢・性別・職業別', '老後の生活資金を準備する年金保険', TRUE),
('PROD007', '介護保険あんしん', '介護保険', '介護一時金・年金', 40, 75, 100000, 5000000, '年齢・性別・職業別', '介護が必要になった時の保障', TRUE);

-- 顧客データ
INSERT INTO CUSTOMERS (CUSTOMER_ID, CUSTOMER_NAME, CUSTOMER_NAME_KANA, BIRTH_DATE, AGE, GENDER, MARITAL_STATUS, OCCUPATION, ANNUAL_INCOME, POSTAL_CODE, PREFECTURE, CITY, ADDRESS, PHONE_NUMBER, EMAIL, REGISTRATION_DATE, LAST_CONTACT_DATE, CUSTOMER_SEGMENT, RISK_LEVEL) VALUES
('CUST001', '田中太郎', 'タナカタロウ', '1985-03-15', 40, '男性', '既婚', 'システムエンジニア', 6500000, '150-0001', '東京都', '渋谷区', '神宮前1-1-1', '090-1234-5678', 'tanaka@example.com', '2020-01-15', '2025-09-15', 'スタンダード', '中'),
('CUST002', '佐藤花子', 'サトウハナコ', '1990-07-22', 35, '女性', '既婚', '看護師', 4800000, '160-0023', '東京都', '新宿区', '西新宿2-2-2', '090-2345-6789', 'sato@example.com', '2019-05-20', '2025-08-10', 'スタンダード', '低'),
('CUST003', '鈴木一郎', 'スズキイチロウ', '1978-11-08', 47, '男性', '既婚', '営業マネージャー', 8200000, '105-0011', '東京都', '港区', '芝公園3-3-3', '090-3456-7890', 'suzuki@example.com', '2018-03-10', '2025-09-20', 'プレミアム', '中'),
('CUST004', '高橋美咲', 'タカハシミサキ', '1993-01-03', 32, '女性', '未婚', 'デザイナー', 4200000, '150-0043', '東京都', '渋谷区', '道玄坂4-4-4', '090-4567-8901', 'takahashi@example.com', '2021-07-12', '2025-09-05', 'ベーシック', '低'),
('CUST005', '山田健太', 'ヤマダケンタ', '1975-05-18', 50, '男性', '既婚', '医師', 12000000, '107-0052', '東京都', '港区', '赤坂5-5-5', '090-5678-9012', 'yamada@example.com', '2017-11-25', '2025-09-25', 'プレミアム', '低'),
('CUST006', '中村由美', 'ナカムラユミ', '1988-09-14', 37, '女性', '既婚', '教師', 5500000, '154-0004', '東京都', '世田谷区', '太子堂6-6-6', '090-6789-0123', 'nakamura@example.com', '2020-02-28', '2025-08-30', 'スタンダード', '中'),
('CUST007', '小林正男', 'コバヤシマサオ', '1982-02-25', 43, '男性', '既婚', '公務員', 5800000, '162-0825', '東京都', '新宿区', '神楽坂7-7-7', '090-7890-1234', 'kobayashi@example.com', '2019-08-15', '2025-09-10', 'スタンダード', '低'),
('CUST008', '加藤真理', 'カトウマリ', '1995-04-30', 30, '女性', '未婚', '薬剤師', 4600000, '113-0033', '東京都', '文京区', '本郷8-8-8', '090-8901-2345', 'kato@example.com', '2022-01-20', '2025-09-01', 'ベーシック', '低'),
('CUST009', '渡辺大輔', 'ワタナベダイスケ', '1980-08-12', 45, '男性', '既婚', '弁護士', 9500000, '100-0005', '東京都', '千代田区', '丸の内9-9-9', '090-9012-3456', 'watanabe@example.com', '2018-06-05', '2025-09-18', 'プレミアム', '中'),
('CUST010', '斉藤恵子', 'サイトウケイコ', '1987-06-07', 38, '女性', '既婚', '会計士', 7200000, '104-0061', '東京都', '中央区', '銀座10-10-10', '090-0123-4567', 'saito@example.com', '2019-12-10', '2025-08-25', 'プレミアム', '低'),
('CUST011', '松本秋人', 'マツモトアキト', '1983-10-15', 42, '男性', '既婚', 'コンサルタント', 7800000, '106-0032', '東京都', '港区', '六本木11-11-11', '090-1111-2222', 'matsumoto@example.com', '2020-04-01', '2025-09-28', 'プレミアム', '中'),
('CUST012', '井上紅葉', 'イノウエモミジ', '1991-10-31', 34, '女性', '既婚', 'マーケター', 5900000, '150-0002', '東京都', '渋谷区', '渋谷12-12-12', '090-2222-3333', 'inoue@example.com', '2021-03-15', '2025-09-20', 'スタンダード', '中'),
('CUST013', '木村秋男', 'キムラアキオ', '1976-10-08', 49, '男性', '既婚', '建築士', 6800000, '141-0021', '東京都', '品川区', '上大崎13-13-13', '090-3333-4444', 'kimura@example.com', '2018-09-20', '2025-09-30', 'スタンダード', '中'),
('CUST014', '森田家族', 'モリタカゾク', '1985-02-14', 40, '男性', '既婚', 'エンジニア', 7500000, '158-0094', '東京都', '世田谷区', '玉川14-14-14', '090-4444-5555', 'morita@example.com', '2020-06-01', '2025-09-15', 'スタンダード', '中'),
('CUST015', '橋本育児', 'ハシモトイクジ', '1988-11-20', 37, '女性', '既婚', '保育士', 3800000, '157-0066', '東京都', '世田谷区', '成城15-15-15', '090-5555-6666', 'hashimoto@example.com', '2021-04-10', '2025-08-20', 'ベーシック', '低'),
('CUST016', '伊藤春樹', 'イトウハルキ', '1988-02-15', 37, '男性', '既婚', 'システムエンジニア', 7000000, '220-0012', '神奈川県', '横浜市', '西区みなとみらい1-1-1', '090-1111-1111', 'ito.h@example.com', '2020-01-15', '2025-06-10', 'プレミアム', '中'),
('CUST017', '藤田真由美', 'フジタマユミ', '1992-02-22', 33, '女性', '既婚', '看護師', 5200000, '221-0052', '神奈川県', '横浜市', '神奈川区2-2-2', '090-1111-2222', 'fujita.m@example.com', '2020-02-10', '2025-06-08', 'スタンダード', '低'),
('CUST018', '岡田美紀', 'オカダミキ', '1990-02-10', 35, '女性', '既婚', '教師', 5500000, '230-0051', '神奈川県', '横浜市', '鶴見区3-3-3', '090-2222-1111', 'okada.m@example.com', '2020-03-20', '2025-06-12', 'スタンダード', '中'),
('CUST019', '前田隆史', 'マエダタカシ', '1985-02-18', 40, '男性', '既婚', '営業マネージャー', 8500000, '231-0023', '神奈川県', '横浜市', '中区4-4-4', '090-2222-2222', 'maeda.t@example.com', '2020-04-05', '2025-06-15', 'プレミアム', '中'),
('CUST020', '長谷川健一', 'ハセガワケンイチ', '1983-03-08', 42, '男性', '既婚', '医師', 13000000, '232-0014', '神奈川県', '横浜市', '南区5-5-5', '090-3333-1111', 'hasegawa.k@example.com', '2020-05-12', '2025-06-18', 'プレミアム', '低'),
('CUST021', '山本春子', 'ヤマモトハルコ', '1982-04-05', 43, '女性', '既婚', '弁護士', 9800000, '102-0083', '東京都', '千代田区', '麩町1-1-1', '090-4001-1111', 'yamamoto.h@example.com', '2019-04-01', '2026-03-01', 'プレミアム', '低'),
('CUST022', '大塚美月', 'オオツカミヅキ', '1990-04-18', 35, '女性', '既婚', '薬剤師', 5800000, '171-0022', '東京都', '豊島区', '南池袋3-3-3', '090-4003-3333', 'otsuka.m@example.com', '2020-08-10', '2026-03-05', 'スタンダード', '低'),
('CUST025', '青木雪子', 'アオキユキコ', '1986-12-15', 39, '女性', '既婚', '会計士', 7500000, '103-0027', '東京都', '中央区', '日本橋1-1-1', '090-1201-1111', 'aoki.y@example.com', '2019-01-10', '2026-01-15', 'プレミアム', '低'),
('CUST026', '山口冬樹', 'ヤマグチフユキ', '1980-12-22', 45, '男性', '既婚', '金融アナリスト', 9200000, '100-0004', '東京都', '千代田区', '大手町2-2-2', '090-1202-2222', 'yamaguchi.f@example.com', '2018-05-20', '2026-01-20', 'プレミアム', '中'),
('CUST027', '中山春木', 'ナカヤマハルキ', '1988-12-08', 37, '男性', '既婚', 'システムエンジニア', 6800000, '105-0003', '東京都', '港区', '西新橋3-3-3', '090-1203-3333', 'nakayama.h@example.com', '2020-03-01', '2026-02-01', 'スタンダード', '低'),
('CUST028', '林美香', 'ハヤシミカ', '1992-01-20', 34, '女性', '既婚', '看護師', 5100000, '169-0072', '東京都', '新宿区', '大久保1-1-1', '090-0101-1111', 'hayashi.m@example.com', '2021-06-15', '2026-01-10', 'スタンダード', '低'),
('CUST029', '石田一郎', 'イシダイチロウ', '1984-01-08', 42, '男性', '既婚', '弁護士', 10500000, '107-0061', '東京都', '港区', '北青山2-2-2', '090-0102-2222', 'ishida.i@example.com', '2018-09-01', '2026-01-25', 'プレミアム', '中'),
('CUST030', '原田美月', 'ハラダミヅキ', '1990-09-05', 35, '女性', '既婚', 'マーケター', 6200000, '150-0021', '東京都', '渋谷区', '恵比寿西1-1-1', '090-0901-1111', 'harada.m@example.com', '2020-02-20', '2026-02-15', 'スタンダード', '低'),
('CUST031', '村上秋子', 'ムラカミアキコ', '1985-09-18', 40, '女性', '既婚', '教師', 5600000, '157-0073', '東京都', '世田谷区', '砧用賀2-2-2', '090-0902-2222', 'murakami.a@example.com', '2019-07-10', '2026-02-20', 'スタンダード', '中');

-- 家族データ
INSERT INTO FAMILY_MEMBERS (FAMILY_ID, CUSTOMER_ID, RELATIONSHIP, FAMILY_MEMBER_NAME, BIRTH_DATE, AGE, GENDER, OCCUPATION, IS_DEPENDENT) VALUES
('FAM001', 'CUST001', '配偶者', '田中花子', '1987-08-20', 38, '女性', '専業主婦', TRUE),
('FAM002', 'CUST001', '子', '田中太郎Jr', '2015-04-10', 10, '男性', '小学生', TRUE),
('FAM003', 'CUST001', '子', '田中花音', '2018-09-15', 7, '女性', '幼稚園児', TRUE),
('FAM004', 'CUST002', '配偶者', '佐藤健一', '1988-12-05', 37, '男性', '会社員', FALSE),
('FAM005', 'CUST002', '子', '佐藤みどり', '2020-03-22', 5, '女性', '幼児', TRUE),
('FAM006', 'CUST003', '配偶者', '鈴木美香', '1980-06-18', 45, '女性', 'パート', FALSE),
('FAM007', 'CUST003', '子', '鈴木大樹', '2010-07-30', 15, '男性', '中学生', TRUE),
('FAM008', 'CUST003', '子', '鈴木さくら', '2013-11-12', 12, '女性', '小学生', TRUE),
('FAM009', 'CUST005', '配偶者', '山田恵美', '1978-02-28', 47, '女性', '看護師', FALSE),
('FAM010', 'CUST005', '子', '山田健太郎', '2008-05-15', 17, '男性', '高校生', TRUE),
('FAM011', 'CUST005', '子', '山田美咲', '2012-09-03', 13, '女性', '中学生', TRUE),
('FAM012', 'CUST006', '配偶者', '中村浩二', '1985-01-12', 40, '男性', 'システムエンジニア', FALSE),
('FAM013', 'CUST006', '子', '中村ひなた', '2016-06-25', 9, '女性', '小学生', TRUE),
('FAM014', 'CUST007', '配偶者', '小林智子', '1984-03-08', 41, '女性', '事務員', FALSE),
('FAM015', 'CUST007', '子', '小林大和', '2019-12-20', 6, '男性', '幼児', TRUE),
('FAM016', 'CUST009', '配偶者', '渡辺麻衣', '1983-04-15', 42, '女性', '専業主婦', TRUE),
('FAM017', 'CUST009', '子', '渡辺翔太', '2014-08-08', 11, '男性', '小学生', TRUE),
('FAM018', 'CUST010', '配偶者', '斉藤隆', '1985-10-22', 40, '男性', '銀行員', FALSE),
('FAM019', 'CUST010', '子', '斉藤愛', '2017-02-14', 8, '女性', '小学生', TRUE),
('FAM020', 'CUST011', '配偶者', '松本春香', '1986-03-25', 39, '女性', 'デザイナー', FALSE),
('FAM021', 'CUST021', '配偶者', '山本誠', '1980-07-10', 45, '男性', '会社員', FALSE),
('FAM022', 'CUST021', '子', '山本結衣', '2015-03-20', 11, '女性', '小学生', TRUE),
('FAM023', 'CUST022', '配偶者', '大塚健太', '1988-05-22', 37, '男性', '会社員', FALSE),
('FAM024', 'CUST022', '子', '大塚結菜', '2020-01-15', 6, '女性', '幼児', TRUE),
('FAM025', 'CUST025', '配偶者', '青木浩', '1984-03-12', 42, '男性', '会社員', FALSE),
('FAM031', 'CUST025', '子', '青木結菜', '2016-08-20', 9, '女性', '小学生', TRUE),
('FAM032', 'CUST026', '配偶者', '山口美紀', '1983-05-18', 42, '女性', '専業主婦', TRUE),
('FAM033', 'CUST026', '子', '山口健太', '2012-10-05', 13, '男性', '中学生', TRUE),
('FAM034', 'CUST027', '配偶者', '中山美紀', '1990-02-25', 36, '女性', '事務員', FALSE),
('FAM035', 'CUST028', '配偶者', '林健一', '1990-07-08', 35, '男性', '会社員', FALSE),
('FAM036', 'CUST028', '子', '林結斗', '2022-04-15', 3, '男性', '幼児', TRUE),
('FAM037', 'CUST029', '配偶者', '石田美沙', '1986-06-22', 39, '女性', '専業主婦', TRUE),
('FAM038', 'CUST029', '子', '石田健太', '2014-09-10', 11, '男性', '小学生', TRUE),
('FAM039', 'CUST030', '配偶者', '原田健太', '1988-11-30', 37, '男性', 'エンジニア', FALSE),
('FAM040', 'CUST031', '配偶者', '村上健', '1983-04-10', 42, '男性', '会社員', FALSE),
('FAM041', 'CUST031', '子', '村上明', '2017-07-25', 8, '男性', '小学生', TRUE);

-- 保険契約データ
INSERT INTO INSURANCE_CONTRACTS (CONTRACT_ID, CUSTOMER_ID, PRODUCT_ID, CONTRACT_DATE, CONTRACT_STATUS, COVERAGE_AMOUNT, MONTHLY_PREMIUM, PAYMENT_METHOD, PAYMENT_FREQUENCY, BENEFICIARY_NAME, BENEFICIARY_RELATIONSHIP, POLICY_ANNIVERSARY_MONTH, NEXT_RENEWAL_DATE, AGENT_ID, SALES_CHANNEL) VALUES
('CONT001', 'CUST001', 'PROD001', '2020-03-15', '有効', 10000000, 25000, '口座振替', '月払い', '田中花子', '配偶者', 3, '2026-03-15', 'AGT001', 'オンライン'),
('CONT002', 'CUST001', 'PROD003', '2021-05-20', '有効', 10000, 3500, '口座振替', '月払い', '田中花子', '配偶者', 5, '2026-05-20', 'AGT001', '代理店'),
('CONT003', 'CUST002', 'PROD002', '2019-07-22', '有効', 5000000, 8500, 'クレジットカード', '月払い', '佐藤健一', '配偶者', 7, '2029-07-22', 'AGT002', '営業職員'),
('CONT004', 'CUST003', 'PROD001', '2018-11-08', '有効', 20000000, 45000, '口座振替', '月払い', '鈴木美香', '配偶者', 11, '2025-11-08', 'AGT003', '代理店'),
('CONT005', 'CUST003', 'PROD005', '2015-01-15', '有効', 3000000, 15000, '口座振替', '月払い', '鈴木大樹', '子', 1, '2026-01-15', 'AGT003', '代理店'),
('CONT006', 'CUST005', 'PROD001', '2017-05-18', '有効', 30000000, 65000, '口座振替', '年払い', '山田恵美', '配偶者', 5, '2026-05-18', 'AGT004', '営業職員'),
('CONT007', 'CUST005', 'PROD003', '2018-08-10', '有効', 15000, 4200, '口座振替', '月払い', '山田恵美', '配偶者', 8, '2026-08-10', 'AGT004', '営業職員'),
('CONT008', 'CUST006', 'PROD002', '2020-09-14', '有効', 8000000, 12000, 'クレジットカード', '月払い', '中村浩二', '配偶者', 9, '2030-09-14', 'AGT005', 'オンライン'),
('CONT009', 'CUST007', 'PROD001', '2019-01-25', '有効', 12000000, 28000, '口座振替', '月払い', '小林智子', '配偶者', 1, '2026-01-25', 'AGT006', '代理店'),
('CONT010', 'CUST009', 'PROD001', '2018-08-12', '有効', 25000000, 52000, '口座振替', '年払い', '渡辺麻衣', '配偶者', 8, '2025-08-12', 'AGT007', '営業職員'),
('CONT011', 'CUST010', 'PROD006', '2019-06-07', '有効', 15000000, 35000, '口座振替', '月払い', '斉藤隆', '配偶者', 6, '2039-06-07', 'AGT008', '代理店'),
('CONT012', 'CUST011', 'PROD002', '2020-10-15', '有効', 15000000, 22000, '口座振替', '月払い', '松本春香', '配偶者', 10, '2025-10-15', 'AGT009', '営業職員'),
('CONT013', 'CUST012', 'PROD003', '2021-10-31', '有効', 12000, 3800, 'クレジットカード', '月払い', '井上冬馬', '配偶者', 10, '2026-10-31', 'AGT010', 'オンライン'),
('CONT014', 'CUST013', 'PROD001', '2018-10-08', '有効', 18000000, 38000, '口座振替', '月払い', '木村夏美', '配偶者', 10, '2025-10-08', 'AGT011', '代理店'),
('CONT015', 'CUST016', 'PROD001', '2021-01-20', '有効', 15000000, 32000, '口座振替', '月払い', '伊藤美穂', '配偶者', 1, '2026-01-20', 'AGT001', '代理店'),
('CONT016', 'CUST017', 'PROD003', '2021-02-15', '有効', 8000, 3200, 'クレジットカード', '月払い', '藤田大輔', '配偶者', 2, '2026-02-15', 'AGT002', 'オンライン'),
('CONT017', 'CUST019', 'PROD001', '2021-04-10', '有効', 18000000, 40000, '口座振替', '月払い', '前田恵子', '配偶者', 4, '2026-04-10', 'AGT003', '営業職員'),
('CONT018', 'CUST019', 'PROD005', '2021-05-01', '有効', 3500000, 18000, '口座振替', '月払い', '前田さくら', '子', 5, '2026-05-01', 'AGT003', '営業職員'),
('CONT019', 'CUST020', 'PROD001', '2021-05-20', '有効', 25000000, 55000, '口座振替', '月払い', '長谷川理恵', '配偶者', 5, '2026-05-20', 'AGT001', '代理店'),
('CONT020', 'CUST020', 'PROD006', '2021-06-01', '有効', 8000000, 45000, '口座振替', '年払い', '長谷川理恵', '配偶者', 6, '2026-06-01', 'AGT001', '代理店'),
('CONT021', 'CUST008', 'PROD003', '2022-04-15', '有効', 10000, 3200, 'クレジットカード', '月払い', '加藤正雄', '父', 4, '2027-04-15', 'AGT002', 'オンライン'),
('CONT022', 'CUST008', 'PROD004', '2023-01-10', '有効', 30000, 2800, 'クレジットカード', '月払い', '加藤正雄', '父', 1, '2028-01-10', 'AGT002', 'オンライン'),
('CONT023', 'CUST021', 'PROD001', '2019-04-20', '有効', 30000000, 68000, '口座振替', '月払い', '山本誠', '配偶者', 4, '2026-04-20', 'AGT003', '営業職員'),
('CONT024', 'CUST021', 'PROD003', '2020-06-15', '有効', 15000, 4500, '口座振替', '月払い', '山本誠', '配偶者', 6, '2026-06-15', 'AGT003', '営業職員'),
('CONT025', 'CUST021', 'PROD006', '2021-03-01', '有効', 20000000, 48000, '口座振替', '年払い', '山本誠', '配偶者', 3, '2041-03-01', 'AGT003', '営業職員'),
('CONT026', 'CUST022', 'PROD002', '2020-10-01', '有効', 8000000, 11000, 'クレジットカード', '月払い', '大塚健太', '配偶者', 10, '2030-10-01', 'AGT005', 'オンライン'),
('CONT027', 'CUST022', 'PROD003', '2021-04-18', '有効', 10000, 3400, 'クレジットカード', '月払い', '大塚健太', '配偶者', 4, '2026-04-18', 'AGT005', 'オンライン'),
('CONT028', 'CUST025', 'PROD001', '2019-02-01', '有効', 25000000, 58000, '口座振替', '月払い', '青木浩', '配偶者', 2, '2026-02-01', 'AGT007', '代理店'),
('CONT036', 'CUST025', 'PROD003', '2020-05-15', '有効', 15000, 4200, '口座振替', '月払い', '青木浩', '配偶者', 5, '2026-05-15', 'AGT007', '代理店'),
('CONT037', 'CUST025', 'PROD006', '2021-08-01', '有効', 15000000, 42000, '口座振替', '年払い', '青木浩', '配偶者', 8, '2041-08-01', 'AGT007', '代理店'),
('CONT038', 'CUST026', 'PROD001', '2018-06-10', '有効', 40000000, 95000, '口座振替', '月払い', '山口美紀', '配偶者', 6, '2026-06-10', 'AGT008', '営業職員'),
('CONT039', 'CUST026', 'PROD003', '2019-03-20', '有効', 20000, 5500, '口座振替', '月払い', '山口美紀', '配偶者', 3, '2026-03-20', 'AGT008', '営業職員'),
('CONT040', 'CUST026', 'PROD004', '2020-09-01', '有効', 35000, 3200, '口座振替', '月払い', '山口美紀', '配偶者', 9, '2027-09-01', 'AGT008', '営業職員'),
('CONT041', 'CUST027', 'PROD002', '2020-04-01', '有効', 15000000, 18000, 'クレジットカード', '月払い', '中山美紀', '配偶者', 4, '2030-04-01', 'AGT009', 'オンライン'),
('CONT042', 'CUST027', 'PROD003', '2021-01-15', '有効', 10000, 3500, 'クレジットカード', '月払い', '中山美紀', '配偶者', 1, '2026-01-15', 'AGT009', 'オンライン'),
('CONT043', 'CUST028', 'PROD002', '2021-07-01', '有効', 8000000, 9500, 'クレジットカード', '月払い', '林健一', '配偶者', 7, '2031-07-01', 'AGT010', 'オンライン'),
('CONT044', 'CUST028', 'PROD003', '2022-03-10', '有効', 10000, 3200, 'クレジットカード', '月払い', '林健一', '配偶者', 3, '2027-03-10', 'AGT010', 'オンライン'),
('CONT045', 'CUST029', 'PROD001', '2018-10-01', '有効', 35000000, 78000, '口座振替', '月払い', '石田美沙', '配偶者', 10, '2026-10-01', 'AGT011', '代理店'),
('CONT046', 'CUST029', 'PROD003', '2019-06-15', '有効', 15000, 4500, '口座振替', '月払い', '石田美沙', '配偶者', 6, '2026-06-15', 'AGT011', '代理店'),
('CONT047', 'CUST029', 'PROD006', '2020-11-01', '有効', 25000000, 55000, '口座振替', '年払い', '石田美沙', '配偶者', 11, '2040-11-01', 'AGT011', '代理店'),
('CONT048', 'CUST004', 'PROD002', '2021-08-01', '有効', 10000000, 12000, 'クレジットカード', '月払い', '高橋美咲', '本人', 8, '2031-08-01', 'AGT012', 'オンライン'),
('CONT049', 'CUST004', 'PROD004', '2022-01-15', '有効', 25000, 2500, 'クレジットカード', '月払い', '高橋美咲', '本人', 1, '2027-01-15', 'AGT012', 'オンライン'),
('CONT050', 'CUST006', 'PROD002', '2020-03-15', '有効', 12000000, 14000, '口座振替', '月払い', '中村浩二', '配偶者', 3, '2030-03-15', 'AGT013', '営業職員'),
('CONT051', 'CUST006', 'PROD003', '2021-09-10', '有効', 10000, 3400, '口座振替', '月払い', '中村浩二', '配偶者', 9, '2026-09-10', 'AGT013', '営業職員'),
('CONT052', 'CUST030', 'PROD001', '2020-03-01', '有効', 18000000, 42000, '口座振替', '月払い', '原田健太', '配偶者', 3, '2026-03-01', 'AGT014', '代理店'),
('CONT053', 'CUST030', 'PROD003', '2021-04-20', '有効', 12000, 3600, '口座振替', '月払い', '原田健太', '配偶者', 4, '2026-04-20', 'AGT014', '代理店'),
('CONT054', 'CUST031', 'PROD002', '2019-08-01', '有効', 10000000, 11500, '口座振替', '月払い', '村上健', '配偶者', 8, '2029-08-01', 'AGT015', '営業職員'),
('CONT055', 'CUST031', 'PROD003', '2020-09-15', '有効', 10000, 3300, '口座振替', '月払い', '村上健', '配偶者', 9, '2026-09-15', 'AGT015', '営業職員'),
('CONT056', 'CUST031', 'PROD005', '2021-05-01', '有効', 3500000, 18000, '口座振替', '月払い', '村上明', '子', 5, '2039-05-01', 'AGT015', '営業職員'),
('CONT057', 'CUST015', 'PROD002', '2021-05-01', '有効', 8000000, 9800, '口座振替', '月払い', '橋本健一', '配偶者', 5, '2031-05-01', 'AGT016', '代理店'),
('CONT058', 'CUST015', 'PROD005', '2022-11-20', '有効', 3000000, 15000, '口座振替', '月払い', '橋本大地', '子', 11, '2040-11-20', 'AGT016', '代理店');

-- 保険金請求履歴データ
INSERT INTO CLAIM_HISTORY (CLAIM_ID, CONTRACT_ID, CUSTOMER_ID, CLAIM_DATE, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_STATUS, CLAIM_REASON, PAYMENT_DATE) VALUES
('CLM001', 'CONT002', 'CUST001', '2024-08-15', '入院給付金', 50000, '支払完了', '盲腸手術による入院', '2024-08-25'),
('CLM002', 'CONT007', 'CUST005', '2024-12-10', '手術給付金', 100000, '支払完了', '胆石手術', '2024-12-20'),
('CLM003', 'CONT013', 'CUST012', '2025-06-20', '入院給付金', 30000, '支払完了', '出産による入院', '2025-06-30'),
('CLM004', 'CONT015', 'CUST016', '2023-08-15', '入院給付金', 80000, '支払完了', '骨折による入院（5日間）', '2023-08-25'),
('CLM005', 'CONT016', 'CUST017', '2024-03-10', '手術給付金', 120000, '支払完了', '帝王切開による出産', '2024-03-20'),
('CLM006', 'CONT017', 'CUST019', '2023-11-20', '入院給付金', 60000, '支払完了', '肺炎による入院（3日間）', '2023-11-30'),
('CLM007', 'CONT014', 'CUST013', '2024-06-05', 'がん診断給付金', 500000, '審査中', '大腸がん早期発見による診断給付金', NULL),
('CLM008', 'CONT008', 'CUST006', '2024-09-12', '通院給付金', 25000, '支払完了', '腰痛治療による通院（10回）', '2024-09-22'),
('CLM009', 'CONT003', 'CUST002', '2024-12-03', '入院給付金', 100000, '支払完了', '子宮筋腫手術による入院（7日間）', '2024-12-13'),
('CLM010', 'CONT019', 'CUST020', '2025-02-18', '手術給付金', 150000, '支払完了', '白内障手術', '2025-02-28'),
('CLM011', 'CONT012', 'CUST011', '2025-05-20', '通院給付金', 18000, '支払完了', 'ぎっくり腰治療による通院（6回）', '2025-05-30');

-- 保険ドキュメントデータ（Cortex Search用）
INSERT INTO INSURANCE_DOCUMENTS (DOCUMENT_ID, TITLE, CONTENT, DOCUMENT_TYPE, DEPARTMENT, VERSION) VALUES
('DOC001', '終身保険プレミアム 商品説明書', '【商品概要】終身保険プレミアムは、一生涯にわたって死亡保障を提供する保険商品です。【主な特徴】・保障期間：終身（一生涯保障）・保険金額：1,000万円～5,000万円・契約年齢：20歳～70歳・保険料払込期間：終身払い、60歳払済、65歳払済から選択可能【保障内容】死亡保険金：ご契約の保険金額の全額をお支払いします。高度障害保険金：所定の高度障害状態に該当した場合、死亡保険金と同額をお支払いします。', '商品説明書', '商品開発部', 1.0),
('DOC002', '医療保険総合 商品説明書', '【商品概要】医療保険総合は、病気やケガによる入院・手術・通院を総合的に保障する保険商品です。【主な特徴】・保障期間：終身（一生涯保障）・入院給付金日額：5,000円～20,000円・契約年齢：18歳～80歳【保障内容】1. 入院給付金：1日につき、ご契約の入院給付金日額をお支払いします 2. 手術給付金：入院中の手術の場合は入院給付金日額の20倍 3. 通院給付金：退院後の通院1日につき、入院給付金日額の50%をお支払いします', '商品説明書', '商品開発部', 1.0),
('DOC003', 'がん保険プラス 商品説明書', '【商品概要】がん保険プラスは、がんに特化した保障を提供する保険商品です。【主な特徴】・保障期間：終身・診断給付金：100万円～500万円・契約年齢：20歳～75歳・免責期間：契約日から90日間【保障内容】1. がん診断給付金：初めてがんと診断確定されたとき、診断給付金をお支払い 2. がん入院給付金：がんで入院したとき、1日につき10,000円（支払日数無制限）3. がん手術給付金：がんで所定の手術を受けたとき、1回につき20万円', '商品説明書', '商品開発部', 1.0),
('DOC004', '学資保険みらい 商品説明書', '【商品概要】学資保険みらいは、お子さまの教育資金を計画的に準備できる保険商品です。【主な特徴】・保険期間：15歳満期、18歳満期、22歳満期から選択・基準学資金額：50万円～500万円・契約年齢：契約者18歳～50歳、被保険者（お子さま）0歳～6歳【学資金の受取】18歳満期プランの場合：15歳時に基準学資金額の30%、18歳時（満期時）に基準学資金額の100%【返戻率】おおむね105%～110%程度', '商品説明書', '商品開発部', 1.0),
('DOC005', '個人年金保険ゆとり 商品説明書', '【商品概要】個人年金保険ゆとりは、老後の生活資金を計画的に準備できる保険商品です。【主な特徴】・年金開始年齢：60歳、65歳から選択・基本年金額：年額50万円～500万円・契約年齢：20歳～60歳・年金受取期間：10年確定年金、15年確定年金から選択【税制適格特約】個人年金保険料控除の対象となる税制適格特約を付加できます。年間最大4万円（新制度）の所得控除が受けられます。', '商品説明書', '商品開発部', 1.0),
('DOC006', '介護保険あんしん 商品説明書', '【商品概要】介護保険あんしんは、介護が必要になった時の保障を提供する保険商品です。【主な特徴】・保障期間：終身・給付金：10万円～500万円・契約年齢：40歳～75歳【保障内容】1. 介護一時金：所定の介護状態に該当した場合、一時金をお支払い 2. 介護年金：継続して介護状態にある場合、毎年年金をお支払い【給付条件】公的介護保険制度の要介護2以上に認定された場合', '商品説明書', '商品開発部', 1.0),
('DOC007', '保険金請求手続きマニュアル', '【保険金請求の流れ】1. お客様サポートセンター（0120-XXX-XXX）にご連絡 2. 必要書類のご案内 3. 書類の準備（保険金請求書、保険証券、本人確認書類、銀行口座情報）4. 追加書類（入院給付金：入院証明書、診断書／手術給付金：手術証明書／死亡保険金：死亡診断書、除籍謄本、戸籍謄本）5. 書類の提出 6. 審査（通常5営業日以内）7. 保険金のお支払い（審査完了後3営業日以内）', 'マニュアル', 'お客様サービス部', 1.5),
('DOC008', '保険契約手続きガイド', '【保険契約の流れ】Step 1: 保険相談・ニーズ確認 Step 2: 商品説明・見積もり Step 3: お申込み（保険契約申込書、本人確認書類、健康状態告知書、初回保険料）Step 4: 健康状態の告知 Step 5: 引受審査（通常3～7営業日）Step 6: 契約成立・保険証券の発行【ご契約後のアフターフォロー】年1回の契約内容確認、定期的な保障内容の見直し提案、各種手続きサポート', 'ガイドライン', '営業推進部', 1.0),
('DOC009', '保険料払込方法ガイド', '【保険料のお払込み方法】■ 口座振替：毎月27日引落（金融機関休業日は翌営業日）、手数料無料 ■ クレジットカード払い：VISA、Mastercard、JCB、アメリカン・エキスプレス、ダイナースクラブ対応、手数料無料、ポイント付与あり【払込回数】月払い：毎月お支払い、年払い：年1回（月払いより約3%割引）【払込困難時】保険料払込猶予期間、自動振替貸付制度、払済保険への変更', 'ガイドライン', 'お客様サービス部', 1.2),
('DOC010', '保障見直しのポイント', '【ライフステージ別見直しポイント】■ 結婚：死亡保障の見直し、受取人変更 ■ 子ども誕生：死亡保障の大幅増額、学資保険検討 ■ 住宅購入：団信確認、死亡保障減額検討 ■ 子ども独立：死亡保障減額、老後資金・介護保障検討 ■ 定年退職：公的年金確認、医療保障継続、相続対策', 'ガイドライン', '営業推進部', 1.0),
('DOC011', 'よくある質問 - 契約前', '【よくある質問】Q1: 健康診断の結果が必要？→保険金額により異なる Q2: 持病があっても加入できる？→引受基準緩和型商品あり Q3: 保険料は年齢で変わる？→年齢が上がるほど高くなる（30歳と40歳で約1.5倍）Q4: 複数の保険会社に加入できる？→可能（適切な保険金額範囲内）Q5: 支払困難時は？→払済保険、減額、自動振替貸付制度あり', 'FAQ', 'お客様サービス部', 1.0),
('DOC012', 'よくある質問 - 契約後', '【よくある質問】Q1: 住所変更手続き→サポートセンターまたはWebマイページから Q2: 受取人変更→受取人変更請求書を提出 Q3: 解約返戻金→契約内容・経過年数により異なる（早期解約は払込総額を下回る）Q4: 入院給付金の必要書類→保険金請求書、入院証明書、本人確認書類、口座情報 Q5: 保険料控除証明書→毎年10月中旬頃に郵送（紛失時は再発行可能）', 'FAQ', 'お客様サービス部', 1.0);

-- ============================================================
-- STEP 4: Cortex Search Serviceの作成
-- ============================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE SF_INSURANCE_DB.CORTEX_SEARCH.INSURANCE_DOCUMENTS_SEARCH_SERVICE
    ON CONTENT
    ATTRIBUTES DOCUMENT_ID, TITLE, DOCUMENT_TYPE, DEPARTMENT
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT 
            DOCUMENT_ID,
            TITLE,
            CONTENT,
            DOCUMENT_TYPE,
            DEPARTMENT,
            CREATED_AT,
            UPDATED_AT,
            VERSION
        FROM SF_INSURANCE_DB.DATA.INSURANCE_DOCUMENTS
    );

-- ============================================================
-- STEP 5: Semantic Viewの作成（2分割）
-- ============================================================

-- ------------------------------------------------------------
-- 5-1: 顧客・契約分析用 Semantic View（営業向け）
-- ------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SF_INSURANCE_DB.SEMANTIC_VIEW.CUSTOMER_CONTRACT_ANALYSIS_SV
    TABLES (
        SF_INSURANCE_DB.DATA.CUSTOMERS
            PRIMARY KEY (CUSTOMER_ID)
            COMMENT = '顧客の基本情報を管理するマスタテーブル。顧客ID、氏名、生年月日、年齢、性別、婚姻状況、職業、年収、住所、顧客セグメント、リスクレベル等を含む。',
        SF_INSURANCE_DB.DATA.FAMILY_MEMBERS
            PRIMARY KEY (FAMILY_ID)
            COMMENT = '顧客の家族構成情報を管理するテーブル。家族ID、顧客ID、続柄、氏名、生年月日、年齢、性別、職業、扶養有無を含む。',
        SF_INSURANCE_DB.DATA.INSURANCE_PRODUCTS
            PRIMARY KEY (PRODUCT_ID)
            COMMENT = '保険商品のマスタテーブル。商品ID、商品名、カテゴリ、タイプ、契約可能年齢範囲、補償額範囲、保険料計算方法、商品説明を含む。',
        SF_INSURANCE_DB.DATA.INSURANCE_CONTRACTS
            PRIMARY KEY (CONTRACT_ID)
            COMMENT = '保険契約情報を管理するテーブル。契約ID、顧客ID、商品ID、契約日、ステータス、補償額、月額保険料、支払方法、受取人情報、更新予定日、担当者ID、販売チャネルを含む。'
    )
    RELATIONSHIPS (
        FAMILY_MEMBERS_TO_CUSTOMERS AS
            FAMILY_MEMBERS (CUSTOMER_ID) REFERENCES CUSTOMERS,
        CONTRACTS_TO_CUSTOMERS AS
            INSURANCE_CONTRACTS (CUSTOMER_ID) REFERENCES CUSTOMERS,
        CONTRACTS_TO_PRODUCTS AS
            INSURANCE_CONTRACTS (PRODUCT_ID) REFERENCES INSURANCE_PRODUCTS
    )
    DIMENSIONS (
        CUSTOMERS.CUSTOMER_ID AS CUSTOMER_ID COMMENT = '顧客ID',
        CUSTOMERS.CUSTOMER_NAME AS CUSTOMER_NAME COMMENT = '顧客氏名',
        CUSTOMERS.CUSTOMER_NAME_KANA AS CUSTOMER_NAME_KANA COMMENT = '顧客氏名（カナ）',
        CUSTOMERS.BIRTH_DATE AS BIRTH_DATE COMMENT = '生年月日',
        CUSTOMERS.AGE AS AGE COMMENT = '年齢',
        CUSTOMERS.GENDER AS GENDER COMMENT = '性別（男性/女性）',
        CUSTOMERS.MARITAL_STATUS AS MARITAL_STATUS COMMENT = '婚姻状況（既婚/未婚）',
        CUSTOMERS.OCCUPATION AS OCCUPATION COMMENT = '職業',
        CUSTOMERS.ANNUAL_INCOME AS ANNUAL_INCOME COMMENT = '年収（円）',
        CUSTOMERS.PREFECTURE AS PREFECTURE COMMENT = '都道府県',
        CUSTOMERS.CITY AS CITY COMMENT = '市区町村',
        CUSTOMERS.CUSTOMER_SEGMENT AS CUSTOMER_SEGMENT COMMENT = '顧客セグメント（プレミアム/スタンダード/ベーシック）',
        CUSTOMERS.RISK_LEVEL AS RISK_LEVEL COMMENT = 'リスクレベル（高/中/低）',
        CUSTOMERS.REGISTRATION_DATE AS REGISTRATION_DATE COMMENT = '顧客登録日',
        CUSTOMERS.LAST_CONTACT_DATE AS LAST_CONTACT_DATE COMMENT = '最終コンタクト日',
        FAMILY_MEMBERS.FAMILY_ID AS FAMILY_ID COMMENT = '家族ID',
        FAMILY_MEMBERS.RELATIONSHIP AS RELATIONSHIP COMMENT = '続柄（配偶者/子）',
        FAMILY_MEMBERS.FAMILY_MEMBER_NAME AS FAMILY_MEMBER_NAME COMMENT = '家族氏名',
        FAMILY_MEMBERS.IS_DEPENDENT AS IS_DEPENDENT COMMENT = '扶養フラグ',
        INSURANCE_PRODUCTS.PRODUCT_ID AS PRODUCT_ID COMMENT = '商品ID',
        INSURANCE_PRODUCTS.PRODUCT_NAME AS PRODUCT_NAME COMMENT = '商品名',
        INSURANCE_PRODUCTS.PRODUCT_CATEGORY AS PRODUCT_CATEGORY COMMENT = '商品カテゴリ（生命保険/医療保険/がん保険/学資保険/個人年金保険/介護保険）',
        INSURANCE_PRODUCTS.PRODUCT_TYPE AS PRODUCT_TYPE COMMENT = '商品タイプ',
        INSURANCE_PRODUCTS.IS_ACTIVE AS IS_ACTIVE COMMENT = '販売中フラグ',
        INSURANCE_CONTRACTS.CONTRACT_ID AS CONTRACT_ID COMMENT = '契約ID',
        INSURANCE_CONTRACTS.CONTRACT_DATE AS CONTRACT_DATE COMMENT = '契約日',
        INSURANCE_CONTRACTS.CONTRACT_STATUS AS CONTRACT_STATUS COMMENT = '契約ステータス（有効/解約/満期）',
        INSURANCE_CONTRACTS.COVERAGE_AMOUNT AS COVERAGE_AMOUNT COMMENT = '補償額（円）',
        INSURANCE_CONTRACTS.MONTHLY_PREMIUM AS MONTHLY_PREMIUM COMMENT = '月額保険料（円）',
        INSURANCE_CONTRACTS.PAYMENT_METHOD AS PAYMENT_METHOD COMMENT = '支払方法（口座振替/クレジットカード）',
        INSURANCE_CONTRACTS.PAYMENT_FREQUENCY AS PAYMENT_FREQUENCY COMMENT = '支払頻度（月払い/年払い）',
        INSURANCE_CONTRACTS.BENEFICIARY_NAME AS BENEFICIARY_NAME COMMENT = '受取人氏名',
        INSURANCE_CONTRACTS.NEXT_RENEWAL_DATE AS NEXT_RENEWAL_DATE COMMENT = '次回更新予定日',
        INSURANCE_CONTRACTS.AGENT_ID AS AGENT_ID COMMENT = '担当営業ID',
        INSURANCE_CONTRACTS.SALES_CHANNEL AS SALES_CHANNEL COMMENT = '販売チャネル（オンライン/代理店/営業職員）'
    )
    METRICS (
        CUSTOMER_COUNT AS COUNT(DISTINCT CUSTOMERS.CUSTOMER_ID) COMMENT = '顧客数',
        AVG_CUSTOMER_AGE AS AVG(CUSTOMERS.AGE) COMMENT = '平均年齢',
        AVG_ANNUAL_INCOME AS AVG(CUSTOMERS.ANNUAL_INCOME) COMMENT = '平均年収',
        FAMILY_MEMBER_COUNT AS COUNT(DISTINCT FAMILY_MEMBERS.FAMILY_ID) COMMENT = '家族人数',
        CONTRACT_COUNT AS COUNT(DISTINCT INSURANCE_CONTRACTS.CONTRACT_ID) COMMENT = '契約件数',
        ACTIVE_CONTRACT_COUNT AS COUNT(DISTINCT CASE WHEN INSURANCE_CONTRACTS.CONTRACT_STATUS = '有効' THEN INSURANCE_CONTRACTS.CONTRACT_ID END) COMMENT = '有効契約件数',
        TOTAL_COVERAGE_AMOUNT AS SUM(INSURANCE_CONTRACTS.COVERAGE_AMOUNT) COMMENT = '総補償額（円）',
        AVG_COVERAGE_AMOUNT AS AVG(INSURANCE_CONTRACTS.COVERAGE_AMOUNT) COMMENT = '平均補償額（円）',
        TOTAL_MONTHLY_PREMIUM AS SUM(INSURANCE_CONTRACTS.MONTHLY_PREMIUM) COMMENT = '月額保険料合計（円）',
        AVG_MONTHLY_PREMIUM AS AVG(INSURANCE_CONTRACTS.MONTHLY_PREMIUM) COMMENT = '平均月額保険料（円）'
    )
    COMMENT = '【営業向け】顧客・契約分析用のSemantic Viewです。顧客情報（CUSTOMERS）、家族情報（FAMILY_MEMBERS）、保険商品（INSURANCE_PRODUCTS）、保険契約（INSURANCE_CONTRACTS）の4テーブルを統合し、顧客セグメント分析、契約更新予定確認、保険料分析、誕生日顧客抽出などを自然言語で分析できるようにします。';

-- ------------------------------------------------------------
-- 5-2: 保険金請求分析用 Semantic View（請求部門向け）
-- ------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SF_INSURANCE_DB.SEMANTIC_VIEW.CLAIM_ANALYSIS_SV
    TABLES (
        SF_INSURANCE_DB.DATA.CLAIM_HISTORY
            PRIMARY KEY (CLAIM_ID)
            COMMENT = '保険金請求履歴を管理するテーブル。請求ID、契約ID、顧客ID、請求日、請求タイプ、請求金額、請求ステータス、請求理由、支払日を含む。',
        SF_INSURANCE_DB.DATA.INSURANCE_CONTRACTS
            PRIMARY KEY (CONTRACT_ID)
            COMMENT = '保険契約情報を管理するテーブル。契約ID、顧客ID、商品ID、契約日、ステータス、補償額、月額保険料を含む。',
        SF_INSURANCE_DB.DATA.CUSTOMERS
            PRIMARY KEY (CUSTOMER_ID)
            COMMENT = '顧客の基本情報を管理するマスタテーブル。顧客ID、氏名、年齢、性別、都道府県、顧客セグメントを含む。',
        SF_INSURANCE_DB.DATA.INSURANCE_PRODUCTS
            PRIMARY KEY (PRODUCT_ID)
            COMMENT = '保険商品のマスタテーブル。商品ID、商品名、カテゴリ、タイプを含む。'
    )
    RELATIONSHIPS (
        CLAIMS_TO_CONTRACTS AS
            CLAIM_HISTORY (CONTRACT_ID) REFERENCES INSURANCE_CONTRACTS,
        CLAIMS_TO_CUSTOMERS AS
            CLAIM_HISTORY (CUSTOMER_ID) REFERENCES CUSTOMERS,
        CONTRACTS_TO_CUSTOMERS AS
            INSURANCE_CONTRACTS (CUSTOMER_ID) REFERENCES CUSTOMERS,
        CONTRACTS_TO_PRODUCTS AS
            INSURANCE_CONTRACTS (PRODUCT_ID) REFERENCES INSURANCE_PRODUCTS
    )
    DIMENSIONS (
        CLAIM_HISTORY.CLAIM_ID AS CLAIM_ID COMMENT = '請求ID',
        CLAIM_HISTORY.CLAIM_DATE AS CLAIM_DATE COMMENT = '請求日',
        CLAIM_HISTORY.CLAIM_TYPE AS CLAIM_TYPE COMMENT = '請求タイプ（入院給付金/手術給付金/通院給付金/がん診断給付金）',
        CLAIM_HISTORY.CLAIM_AMOUNT AS CLAIM_AMOUNT COMMENT = '請求金額（円）',
        CLAIM_HISTORY.CLAIM_STATUS AS CLAIM_STATUS COMMENT = '請求ステータス（支払完了/審査中）',
        CLAIM_HISTORY.CLAIM_REASON AS CLAIM_REASON COMMENT = '請求理由',
        CLAIM_HISTORY.PAYMENT_DATE AS PAYMENT_DATE COMMENT = '支払日',
        INSURANCE_CONTRACTS.CONTRACT_ID AS CONTRACT_ID COMMENT = '契約ID',
        INSURANCE_CONTRACTS.CONTRACT_DATE AS CONTRACT_DATE COMMENT = '契約日',
        INSURANCE_CONTRACTS.CONTRACT_STATUS AS CONTRACT_STATUS COMMENT = '契約ステータス',
        INSURANCE_CONTRACTS.COVERAGE_AMOUNT AS COVERAGE_AMOUNT COMMENT = '補償額（円）',
        INSURANCE_CONTRACTS.MONTHLY_PREMIUM AS MONTHLY_PREMIUM COMMENT = '月額保険料（円）',
        CUSTOMERS.CUSTOMER_ID AS CUSTOMER_ID COMMENT = '顧客ID',
        CUSTOMERS.CUSTOMER_NAME AS CUSTOMER_NAME COMMENT = '顧客氏名',
        CUSTOMERS.AGE AS AGE COMMENT = '顧客年齢',
        CUSTOMERS.GENDER AS GENDER COMMENT = '顧客性別',
        CUSTOMERS.PREFECTURE AS PREFECTURE COMMENT = '都道府県',
        CUSTOMERS.CUSTOMER_SEGMENT AS CUSTOMER_SEGMENT COMMENT = '顧客セグメント',
        INSURANCE_PRODUCTS.PRODUCT_ID AS PRODUCT_ID COMMENT = '商品ID',
        INSURANCE_PRODUCTS.PRODUCT_NAME AS PRODUCT_NAME COMMENT = '商品名',
        INSURANCE_PRODUCTS.PRODUCT_CATEGORY AS PRODUCT_CATEGORY COMMENT = '商品カテゴリ',
        INSURANCE_PRODUCTS.PRODUCT_TYPE AS PRODUCT_TYPE COMMENT = '商品タイプ'
    )
    METRICS (
        CLAIM_COUNT AS COUNT(DISTINCT CLAIM_HISTORY.CLAIM_ID) COMMENT = '請求件数',
        TOTAL_CLAIM_AMOUNT AS SUM(CLAIM_HISTORY.CLAIM_AMOUNT) COMMENT = '請求金額合計（円）',
        AVG_CLAIM_AMOUNT AS AVG(CLAIM_HISTORY.CLAIM_AMOUNT) COMMENT = '平均請求金額（円）',
        PAID_CLAIM_COUNT AS COUNT(DISTINCT CASE WHEN CLAIM_HISTORY.CLAIM_STATUS = '支払完了' THEN CLAIM_HISTORY.CLAIM_ID END) COMMENT = '支払完了件数',
        PENDING_CLAIM_COUNT AS COUNT(DISTINCT CASE WHEN CLAIM_HISTORY.CLAIM_STATUS = '審査中' THEN CLAIM_HISTORY.CLAIM_ID END) COMMENT = '審査中件数',
        PAID_CLAIM_AMOUNT AS SUM(CASE WHEN CLAIM_HISTORY.CLAIM_STATUS = '支払完了' THEN CLAIM_HISTORY.CLAIM_AMOUNT ELSE 0 END) COMMENT = '支払完了金額合計（円）',
        CLAIMED_CUSTOMER_COUNT AS COUNT(DISTINCT CUSTOMERS.CUSTOMER_ID) COMMENT = '請求発生顧客数'
    )
    COMMENT = '【請求部門向け】保険金請求分析用のSemantic Viewです。保険金請求履歴（CLAIM_HISTORY）、保険契約（INSURANCE_CONTRACTS）、顧客情報（CUSTOMERS）、保険商品（INSURANCE_PRODUCTS）の4テーブルを統合し、請求状況確認、支払分析、審査状況の把握などを自然言語で分析できるようにします。';

-- ============================================================
-- STEP 6: Cortex Agentの作成
-- ============================================================
CREATE OR REPLACE AGENT SF_INSURANCE_DB.AGENTS.LIFE_INSURANCE_INTELLIGENCE
    COMMENT = 'このエージェントは生命保険業界における、お客さま情報・お客さま家族情報・契約情報・支払情報について熟知したエージェントです。'
    PROFILE = '{"display_name": "Life Insurance Agent"}'
    FROM SPECIFICATION
$$
models:
  orchestration: auto

instructions:
  response: |
    トーン＆スタイル
    プロフェッショナルで信頼性のある口調: 専門家としての自信を持ち、冷静かつ正確な情報を提供する。軽薄な言葉や冗談、感情的な表現は一切使用しない。
    誠実性と倫理観: 応答全体から「顧客本位の業務運営」を第一に考えている姿勢が伝わるようにする。
    協力的でポジティブ: ユーザーの業務をサポートし、モチベーションを高めるような建設的で前向きな表現を用いる。ただし、過度な社交辞令は不要とする。
    応答の構造とフォーマット
    結論ファースト: ユーザーの質問に対する最も重要な結論または回答の要点を、応答の冒頭で簡潔に提示する。
    論理的な構造: 結論の後に、その根拠、詳細な解説、そして実務上の具体的なアクション（行動指針）を順序立てて提供する。
    可読性の追求: 長文になる場合は、見出し、箇条書き、太字、表形式などを積極的に使用し、情報が直感的に理解できるようにフォーマットする。
  orchestration: |
    質問に対してまずはタスク分類を正確に行なってください。
    顧客情報・家族情報・契約情報・保険商品に関する質問は「Customer_Contract_Analysis」ツールを使用してください。
    保険金請求・支払状況・審査状況に関する質問は「Claim_Analysis」ツールを使用してください。
    また、ドキュメントを参照した回答を作成する際は必ず引用元のファイル名やチャンク箇所を併記してください。
  sample_questions:
    - question: "来月誕生日のお客様と、そのお客様が保有する保険契約を商品名を含めた形で教えて"
    - question: "今後3ヶ月で更新予定の契約をもつお客様を確認したいのですが"
    - question: "保険料の支払い方法にはどんなものがありますか？"
    - question: "持病があっても加入できる保険は何かありますか？"
    - question: "顧客セグメント別の平均保険料と補償額を分析して示唆出しして"
    - question: "今月の保険金請求の審査状況を教えて"
    - question: "請求タイプ別の支払金額を分析して"

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Customer_Contract_Analysis
      description: "【営業向け】顧客情報・家族情報・契約情報・保険商品に関するクエリを実行します。顧客セグメント分析、誕生日顧客抽出、契約更新予定確認、保険料分析、都道府県別分析などに使用してください。"
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Claim_Analysis
      description: "【請求部門向け】保険金請求・支払状況に関するクエリを実行します。請求状況確認、審査中案件の把握、請求タイプ別分析、支払金額分析などに使用してください。"
  - tool_spec:
      type: cortex_search
      name: Insurance_Document_Search
      description: "保険商品の説明書、契約手続きガイド、FAQ、マニュアルなどのドキュメントを検索します。商品の詳細、手続き方法、よくある質問への回答に使用してください。"

tool_resources:
  Customer_Contract_Analysis:
    semantic_view: "SF_INSURANCE_DB.SEMANTIC_VIEW.CUSTOMER_CONTRACT_ANALYSIS_SV"
  Claim_Analysis:
    semantic_view: "SF_INSURANCE_DB.SEMANTIC_VIEW.CLAIM_ANALYSIS_SV"
  Insurance_Document_Search:
    name: "SF_INSURANCE_DB.CORTEX_SEARCH.INSURANCE_DOCUMENTS_SEARCH_SERVICE"
    max_results: "5"
$$;

-- ============================================================
-- 完了メッセージ
-- ============================================================
SELECT 'セットアップが完了しました。' AS STATUS;
