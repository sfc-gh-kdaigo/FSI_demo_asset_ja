-- =====================================================
-- SNOW_RISK 環境構築
-- リスク管理向けデモ環境
-- =====================================================

-- =============================================================================
-- 1. ロール・ウェアハウス設定
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS SNOW_RISK_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'SnowBank リスク管理デモ用ウェアハウス';

USE WAREHOUSE SNOW_RISK_WH;

-- =============================================================================
-- 2. データベース・スキーマ作成
-- =============================================================================
CREATE DATABASE IF NOT EXISTS SNOW_RISK;
CREATE SCHEMA IF NOT EXISTS SNOW_RISK.DATA;
CREATE SCHEMA IF NOT EXISTS SNOW_RISK.AI;

USE DATABASE SNOW_RISK;
USE SCHEMA DATA;

-- =============================================================================
-- 3. テーブル作成（DDL）
-- =============================================================================

-- 3.1 DIM_RATING（格付マスタ）
CREATE OR REPLACE TABLE DIM_RATING (
    RATING_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    RATING_CODE VARCHAR(10) NOT NULL,
    RATING_NAME VARCHAR(50) NOT NULL,
    RATING_RANK NUMBER(2,0) NOT NULL,
    PD_LOWER NUMBER(10,6),
    PD_UPPER NUMBER(10,6),
    PD_CENTRAL NUMBER(10,6),
    EXTERNAL_RATING_SP VARCHAR(10),
    EXTERNAL_RATING_MOODYS VARCHAR(10),
    DESCRIPTION VARCHAR(200),
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='格付マスタ：内部格付と外部格付の対応';

-- 3.2 DIM_INDUSTRY（業種マスタ）
CREATE OR REPLACE TABLE DIM_INDUSTRY (
    INDUSTRY_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    INDUSTRY_CODE VARCHAR(10) NOT NULL,
    INDUSTRY_NAME VARCHAR(100) NOT NULL,
    INDUSTRY_CATEGORY VARCHAR(50),
    BOJ_INDUSTRY_CODE VARCHAR(10),
    RISK_WEIGHT_STANDARD NUMBER(5,2),
    DESCRIPTION VARCHAR(200),
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='業種マスタ：日銀業種分類対応';

-- 3.3 DIM_DEPARTMENT（部門マスタ）
CREATE OR REPLACE TABLE DIM_DEPARTMENT (
    DEPARTMENT_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    DEPARTMENT_CODE VARCHAR(10) NOT NULL,
    DEPARTMENT_NAME VARCHAR(100) NOT NULL,
    DEPARTMENT_TYPE VARCHAR(50),
    PARENT_DEPARTMENT_CODE VARCHAR(10),
    MANAGER_NAME VARCHAR(50),
    LOCATION VARCHAR(50),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='部門マスタ：営業部門・管理部門の階層構造';

-- 3.4 DIM_PRODUCT（プロダクトマスタ）
CREATE OR REPLACE TABLE DIM_PRODUCT (
    PRODUCT_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    PRODUCT_CODE VARCHAR(20) NOT NULL,
    PRODUCT_NAME VARCHAR(100) NOT NULL,
    PRODUCT_CATEGORY VARCHAR(50),
    EXPOSURE_CLASS VARCHAR(50),
    CCF NUMBER(5,4) DEFAULT 1.0,
    LGD_STANDARD NUMBER(5,4) DEFAULT 0.45,
    DESCRIPTION VARCHAR(500),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='プロダクトマスタ：貸出商品・コミットメントライン等';

-- 3.5 DIM_COUNTERPARTY（取引先マスタ）
CREATE OR REPLACE TABLE DIM_COUNTERPARTY (
    COUNTERPARTY_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    COUNTERPARTY_CODE VARCHAR(20) NOT NULL,
    COUNTERPARTY_NAME VARCHAR(200) NOT NULL,
    COUNTERPARTY_NAME_KANA VARCHAR(200),
    COUNTERPARTY_TYPE VARCHAR(20),
    RATING_KEY NUMBER(38,0),
    INDUSTRY_KEY NUMBER(38,0),
    DEPARTMENT_KEY NUMBER(38,0),
    ESTABLISHMENT_DATE DATE,
    CAPITAL_AMOUNT NUMBER(18,0),
    EMPLOYEE_COUNT NUMBER(10,0),
    ANNUAL_SALES NUMBER(18,0),
    LISTED_FLAG BOOLEAN DEFAULT FALSE,
    CONSOLIDATED_FLAG BOOLEAN DEFAULT FALSE,
    COUNTRY_CODE VARCHAR(3) DEFAULT 'JPN',
    PREFECTURE VARCHAR(20),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='取引先マスタ：法人・個人の統合マスタ';

-- 3.6 FACT_LOAN_DETAIL（貸出金明細ファクト）
CREATE OR REPLACE TABLE FACT_LOAN_DETAIL (
    LOAN_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    LOAN_NUMBER VARCHAR(20) NOT NULL,
    COUNTERPARTY_KEY NUMBER(38,0) NOT NULL,
    PRODUCT_KEY NUMBER(38,0) NOT NULL,
    DEPARTMENT_KEY NUMBER(38,0) NOT NULL,
    RATING_KEY NUMBER(38,0),
    BASE_DATE DATE NOT NULL,
    LOAN_START_DATE DATE,
    LOAN_MATURITY_DATE DATE,
    ORIGINAL_AMOUNT NUMBER(18,2),
    OUTSTANDING_AMOUNT NUMBER(18,2) NOT NULL,
    UNDRAWN_AMOUNT NUMBER(18,2) DEFAULT 0,
    INTEREST_RATE NUMBER(8,5),
    COLLATERAL_TYPE VARCHAR(50),
    COLLATERAL_VALUE NUMBER(18,2) DEFAULT 0,
    GUARANTEE_TYPE VARCHAR(50),
    GUARANTEE_VALUE NUMBER(18,2) DEFAULT 0,
    CURRENCY_CODE VARCHAR(3) DEFAULT 'JPY',
    EXPOSURE_CLASS VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='貸出金明細ファクト：統一されたエクスポージャーデータ';

-- 3.7 FACT_INTERNAL_RISK（内部リスク計測結果ファクト）
CREATE OR REPLACE TABLE FACT_INTERNAL_RISK (
    INTERNAL_RISK_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    LOAN_KEY NUMBER(38,0) NOT NULL,
    BASE_DATE DATE NOT NULL,
    EAD NUMBER(18,2) NOT NULL,
    PD NUMBER(10,6) NOT NULL,
    LGD NUMBER(5,4) NOT NULL,
    MATURITY_YEARS NUMBER(5,2) DEFAULT 2.5,
    EL NUMBER(18,2),
    UL NUMBER(18,2),
    ECONOMIC_CAPITAL NUMBER(18,2),
    RISK_CONTRIBUTION NUMBER(18,2),
    CALCULATION_METHOD VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='内部リスク計測結果ファクト：EL/UL等の内部管理指標';

-- 3.8 FACT_REGULATORY_RISK（規制資本計算結果ファクト）
CREATE OR REPLACE TABLE FACT_REGULATORY_RISK (
    REGULATORY_RISK_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    LOAN_KEY NUMBER(38,0) NOT NULL,
    BASE_DATE DATE NOT NULL,
    EAD NUMBER(18,2) NOT NULL,
    RISK_WEIGHT NUMBER(5,4) NOT NULL,
    RWA NUMBER(18,2) NOT NULL,
    EXPOSURE_CLASS_REGULATORY VARCHAR(50),
    APPROACH_TYPE VARCHAR(50),
    CRM_TYPE VARCHAR(50),
    CRM_VALUE NUMBER(18,2) DEFAULT 0,
    K_IRB NUMBER(10,6),
    SCALING_FACTOR NUMBER(5,4) DEFAULT 1.06,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='規制資本計算結果ファクト：RWA等の規制資本指標';

-- 3.9 RISK_DOCUMENT（リスク管理ドキュメント）
CREATE OR REPLACE TABLE RISK_DOCUMENT (
    DOCUMENT_ID VARCHAR(20) NOT NULL,
    TITLE VARCHAR(200) NOT NULL,
    CONTENT VARCHAR(16777216) NOT NULL,
    DOCUMENT_TYPE VARCHAR(50),
    CATEGORY VARCHAR(50),
    KEYWORDS VARCHAR(500),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    VERSION NUMBER(10,0) DEFAULT 1
) COMMENT='リスク管理ドキュメント：規程、バーゼル解説、マニュアル';

ALTER TABLE RISK_DOCUMENT SET CHANGE_TRACKING = TRUE;

-- =============================================================================
-- 4. サンプルデータ投入
-- =============================================================================

-- 4.1 DIM_RATING（15件）
INSERT INTO DIM_RATING (RATING_CODE, RATING_NAME, RATING_RANK, PD_LOWER, PD_UPPER, PD_CENTRAL, EXTERNAL_RATING_SP, EXTERNAL_RATING_MOODYS, DESCRIPTION)
VALUES
('1', '1（最優良）', 1, 0.000000, 0.000100, 0.000030, 'AAA', 'Aaa', '最も信用力が高い'),
('2', '2（優良上位）', 2, 0.000100, 0.000300, 0.000150, 'AA+', 'Aa1', '信用力が非常に高い'),
('3', '3（優良）', 3, 0.000300, 0.000600, 0.000400, 'AA', 'Aa2', '信用力が高い'),
('4', '4（良好上位）', 4, 0.000600, 0.001200, 0.000800, 'AA-', 'Aa3', '信用力が比較的高い'),
('5', '5（良好）', 5, 0.001200, 0.002500, 0.001800, 'A+', 'A1', '信用力は良好'),
('6', '6（正常上位）', 6, 0.002500, 0.005000, 0.003500, 'A', 'A2', '信用力は標準以上'),
('7', '7（正常）', 7, 0.005000, 0.010000, 0.007000, 'A-', 'A3', '信用力は標準'),
('8', '8（正常下位）', 8, 0.010000, 0.020000, 0.014000, 'BBB+', 'Baa1', '信用力は標準下位'),
('9', '9（要注意先）', 9, 0.020000, 0.050000, 0.030000, 'BBB', 'Baa2', '要注意先'),
('10', '10（要管理先）', 10, 0.050000, 0.100000, 0.070000, 'BBB-', 'Baa3', '要管理先'),
('11', '11（破綻懸念先上位）', 11, 0.100000, 0.200000, 0.140000, 'BB', 'Ba2', '破綻懸念先上位'),
('12', '12（破綻懸念先）', 12, 0.200000, 0.400000, 0.280000, 'B', 'B2', '破綻懸念先'),
('13', '13（実質破綻先）', 13, 0.400000, 0.700000, 0.500000, 'CCC', 'Caa', '実質破綻先'),
('14', '14（破綻先）', 14, 0.700000, 1.000000, 0.850000, 'CC', 'Ca', '破綻先'),
('15', '15（デフォルト）', 15, 1.000000, 1.000000, 1.000000, 'D', 'D', 'デフォルト');

-- 4.2 DIM_INDUSTRY（30件）
INSERT INTO DIM_INDUSTRY (INDUSTRY_CODE, INDUSTRY_NAME, INDUSTRY_CATEGORY, BOJ_INDUSTRY_CODE, RISK_WEIGHT_STANDARD)
VALUES
('IND001', '食品製造業', '製造業', '09', 100.00),
('IND002', '化学工業', '製造業', '10', 100.00),
('IND003', '鉄鋼業', '製造業', '11', 100.00),
('IND004', '非鉄金属製造業', '製造業', '12', 100.00),
('IND005', '金属製品製造業', '製造業', '13', 100.00),
('IND006', '電気機械器具製造業', '製造業', '15', 100.00),
('IND007', '輸送用機械器具製造業', '製造業', '17', 100.00),
('IND008', 'その他製造業', '製造業', '18', 100.00),
('IND009', '建設業', '建設業', '06', 100.00),
('IND010', '不動産業', '不動産業', '25', 100.00),
('IND011', '卸売業', '卸売・小売業', '19', 100.00),
('IND012', '小売業', '卸売・小売業', '20', 100.00),
('IND013', '運輸業', '運輸・通信業', '21', 100.00),
('IND014', '通信業', '運輸・通信業', '22', 100.00),
('IND015', '電気・ガス業', 'インフラ', '05', 65.00),
('IND016', '銀行業', '金融・保険業', '23', 20.00),
('IND017', '証券業', '金融・保険業', '23', 100.00),
('IND018', '保険業', '金融・保険業', '23', 100.00),
('IND019', 'その他金融業', '金融・保険業', '23', 100.00),
('IND020', '医療業', 'サービス業', '27', 100.00),
('IND021', '福祉業', 'サービス業', '27', 100.00),
('IND022', '宿泊業', 'サービス業', '26', 100.00),
('IND023', '飲食業', 'サービス業', '26', 100.00),
('IND024', '情報サービス業', 'サービス業', '22', 100.00),
('IND025', '専門サービス業', 'サービス業', '27', 100.00),
('IND026', '政府', '公共', '01', 0.00),
('IND027', '地方公共団体', '公共', '02', 0.00),
('IND028', '個人（住宅ローン）', '個人', '30', 35.00),
('IND029', '個人（消費者ローン）', '個人', '30', 75.00),
('IND030', '農林水産業', '一次産業', '04', 100.00);

-- 4.3 DIM_DEPARTMENT（20件）
INSERT INTO DIM_DEPARTMENT (DEPARTMENT_CODE, DEPARTMENT_NAME, DEPARTMENT_TYPE, PARENT_DEPARTMENT_CODE, MANAGER_NAME, LOCATION)
VALUES
('DEP001', '法人営業第一部', '営業', NULL, '山田 太郎', '本店'),
('DEP002', '法人営業第二部', '営業', NULL, '佐藤 花子', '本店'),
('DEP003', '法人営業第三部', '営業', NULL, '鈴木 一郎', '本店'),
('DEP004', '中小企業営業部', '営業', NULL, '高橋 健一', '本店'),
('DEP005', '国際営業部', '営業', NULL, '田中 美咲', '本店'),
('DEP006', '個人営業第一部', '営業', NULL, '渡辺 修', '本店'),
('DEP007', '個人営業第二部', '営業', NULL, '伊藤 智子', '本店'),
('DEP008', '住宅ローン推進部', '営業', NULL, '加藤 隆', '本店'),
('DEP009', '東京営業部', '営業', 'DEP001', '吉田 明', '東京'),
('DEP010', '大阪営業部', '営業', 'DEP001', '山本 誠', '大阪'),
('DEP011', '名古屋営業部', '営業', 'DEP002', '中村 真一', '名古屋'),
('DEP012', '福岡営業部', '営業', 'DEP002', '小林 裕', '福岡'),
('DEP013', '札幌営業部', '営業', 'DEP003', '加藤 直人', '札幌'),
('DEP014', 'リスク管理部', '管理', NULL, '井上 浩二', '本店'),
('DEP015', '審査部', '管理', NULL, '木村 正義', '本店'),
('DEP016', '経営企画部', '管理', NULL, '林 美紀', '本店'),
('DEP017', '財務部', '管理', NULL, '斉藤 洋子', '本店'),
('DEP018', 'コンプライアンス部', '管理', NULL, '清水 健太', '本店'),
('DEP019', '海外拠点（NY）', '海外', 'DEP005', 'John Smith', 'ニューヨーク'),
('DEP020', '海外拠点（SG）', '海外', 'DEP005', 'Chen Wei', 'シンガポール');

-- 4.4 DIM_PRODUCT（30件）
INSERT INTO DIM_PRODUCT (PRODUCT_CODE, PRODUCT_NAME, PRODUCT_CATEGORY, EXPOSURE_CLASS, CCF, LGD_STANDARD, DESCRIPTION)
VALUES
('PRD001', '証書貸付（短期）', '貸出', '事業法人', 1.0000, 0.4500, '1年以内の証書貸付'),
('PRD002', '証書貸付（長期）', '貸出', '事業法人', 1.0000, 0.4500, '1年超の証書貸付'),
('PRD003', '手形貸付', '貸出', '事業法人', 1.0000, 0.4500, '手形による貸付'),
('PRD004', '当座貸越', '貸出', '事業法人', 0.7500, 0.4500, '当座貸越契約'),
('PRD005', 'コミットメントライン', 'オフバランス', '事業法人', 0.7500, 0.4500, 'コミットメントライン契約'),
('PRD006', 'シンジケートローン', '貸出', '事業法人', 1.0000, 0.4500, '協調融資'),
('PRD007', 'プロジェクトファイナンス', '貸出', '特定貸付', 1.0000, 0.4500, 'プロジェクト向け融資'),
('PRD008', '不動産ノンリコースローン', '貸出', '特定貸付', 1.0000, 0.4500, '不動産担保ローン（ノンリコース）'),
('PRD009', '住宅ローン（変動）', '貸出', 'リテール（居住用不動産）', 1.0000, 0.2500, '住宅ローン変動金利型'),
('PRD010', '住宅ローン（固定）', '貸出', 'リテール（居住用不動産）', 1.0000, 0.2500, '住宅ローン固定金利型'),
('PRD011', '住宅ローン（フラット35）', '貸出', 'リテール（居住用不動産）', 1.0000, 0.2500, 'フラット35'),
('PRD012', 'アパートローン', '貸出', '事業法人', 1.0000, 0.3500, 'アパート・マンション建設ローン'),
('PRD013', 'カードローン', '貸出', 'リテール（その他）', 1.0000, 0.7500, '個人向けカードローン'),
('PRD014', 'マイカーローン', '貸出', 'リテール（その他）', 1.0000, 0.4500, '自動車購入ローン'),
('PRD015', '教育ローン', '貸出', 'リテール（その他）', 1.0000, 0.4500, '教育資金ローン'),
('PRD016', '設備資金貸付', '貸出', '事業法人', 1.0000, 0.4500, '設備投資向け融資'),
('PRD017', '運転資金貸付', '貸出', '事業法人', 1.0000, 0.4500, '運転資金向け融資'),
('PRD018', '輸出入金融', '貸出', '事業法人', 1.0000, 0.4500, '貿易金融'),
('PRD019', '保証（信用保証）', 'オフバランス', '事業法人', 1.0000, 0.4500, '信用保証'),
('PRD020', '保証（履行保証）', 'オフバランス', '事業法人', 0.5000, 0.4500, '履行保証'),
('PRD021', 'スタンドバイLC', 'オフバランス', '事業法人', 1.0000, 0.4500, 'スタンドバイ信用状'),
('PRD022', '中小企業向け制度融資', '貸出', '中小企業', 1.0000, 0.4500, '政府系制度融資'),
('PRD023', '創業支援融資', '貸出', '中小企業', 1.0000, 0.4500, '創業者向け融資'),
('PRD024', '事業承継融資', '貸出', '中小企業', 1.0000, 0.4500, '事業承継支援融資'),
('PRD025', 'ABL（動産担保融資）', '貸出', '事業法人', 1.0000, 0.3500, '在庫・売掛金担保融資'),
('PRD026', 'ファクタリング', 'オフバランス', '事業法人', 1.0000, 0.4500, '売掛債権買取'),
('PRD027', 'リース', 'オフバランス', '事業法人', 1.0000, 0.4500, 'ファイナンスリース'),
('PRD028', 'ソブリン向け貸付', '貸出', 'ソブリン', 1.0000, 0.4500, '政府向け貸付'),
('PRD029', '金融機関向け貸付', '貸出', '金融機関', 1.0000, 0.4500, '金融機関向けコール等'),
('PRD030', '自治体向け貸付', '貸出', '公共', 1.0000, 0.4500, '地方公共団体向け貸付');

-- 4.5 DIM_COUNTERPARTY（500件）
INSERT INTO DIM_COUNTERPARTY (COUNTERPARTY_CODE, COUNTERPARTY_NAME, COUNTERPARTY_NAME_KANA, COUNTERPARTY_TYPE, RATING_KEY, INDUSTRY_KEY, DEPARTMENT_KEY, ESTABLISHMENT_DATE, CAPITAL_AMOUNT, EMPLOYEE_COUNT, ANNUAL_SALES, LISTED_FLAG, PREFECTURE)
SELECT
    'CP' || LPAD(SEQ4()::VARCHAR, 5, '0'),
    CASE 
        WHEN SEQ4() % 10 = 0 THEN '株式会社' || ARRAY_CONSTRUCT('山田製作所', '鈴木工業', '佐藤商事', '田中建設', '高橋電機', '渡辺物産', '伊藤食品', '山本化学', '中村機械', '小林金属')[UNIFORM(0, 9, RANDOM())::INT]
        WHEN SEQ4() % 10 = 1 THEN ARRAY_CONSTRUCT('東京', '大阪', '名古屋', '横浜', '神戸', '福岡', '札幌', '仙台', '広島', '京都')[UNIFORM(0, 9, RANDOM())::INT] || ARRAY_CONSTRUCT('精密', '重工業', 'テクノ', 'エンジニアリング', 'サービス')[UNIFORM(0, 4, RANDOM())::INT] || '株式会社'
        WHEN SEQ4() % 10 = 2 THEN '有限会社' || ARRAY_CONSTRUCT('松本商店', '井上工務店', '木村運輸', '林不動産', '斉藤設備')[UNIFORM(0, 4, RANDOM())::INT]
        WHEN SEQ4() % 10 = 3 THEN '合同会社' || ARRAY_CONSTRUCT('グローバルトレード', 'テックソリューション', 'エコサービス', 'ライフサポート', 'フューチャーデザイン')[UNIFORM(0, 4, RANDOM())::INT]
        WHEN SEQ4() % 10 = 4 THEN ARRAY_CONSTRUCT('ABC', 'XYZ', 'JKL', 'MNO', 'PQR')[UNIFORM(0, 4, RANDOM())::INT] || 'ホールディングス株式会社'
        WHEN SEQ4() % 10 = 5 THEN '医療法人' || ARRAY_CONSTRUCT('仁愛会', '慈恵会', '健康会', '明生会', '幸和会')[UNIFORM(0, 4, RANDOM())::INT]
        WHEN SEQ4() % 10 = 6 THEN '社会福祉法人' || ARRAY_CONSTRUCT('あおぞら', 'ひまわり', 'さくら', 'もみじ', 'いちょう')[UNIFORM(0, 4, RANDOM())::INT]
        WHEN SEQ4() % 10 = 7 THEN '学校法人' || ARRAY_CONSTRUCT('明星学園', '青雲学院', '緑風学園', '白鳥学院', '黄金学園')[UNIFORM(0, 4, RANDOM())::INT]
        WHEN SEQ4() % 10 = 8 THEN ARRAY_CONSTRUCT('山田', '鈴木', '佐藤', '田中', '高橋', '渡辺', '伊藤', '山本', '中村', '小林')[UNIFORM(0, 9, RANDOM())::INT] || ' ' || ARRAY_CONSTRUCT('太郎', '花子', '一郎', '美咲', '健一')[UNIFORM(0, 4, RANDOM())::INT]
        ELSE '株式会社' || ARRAY_CONSTRUCT('スノー', 'クラウド', 'データ', 'AI', 'テック')[UNIFORM(0, 4, RANDOM())::INT] || ARRAY_CONSTRUCT('ジャパン', 'グループ', 'コーポレーション', 'インターナショナル', 'ソリューションズ')[UNIFORM(0, 4, RANDOM())::INT]
    END,
    NULL,
    CASE 
        WHEN SEQ4() % 10 = 8 THEN '個人'
        ELSE '法人'
    END,
    UNIFORM(1, 12, RANDOM())::INT,
    UNIFORM(1, 30, RANDOM())::INT,
    UNIFORM(1, 13, RANDOM())::INT,
    DATEADD('day', -UNIFORM(365, 36500, RANDOM())::INT, CURRENT_DATE()),
    CASE WHEN SEQ4() % 10 = 8 THEN NULL ELSE UNIFORM(1, 100, RANDOM())::INT * 10000000 END,
    CASE WHEN SEQ4() % 10 = 8 THEN NULL ELSE UNIFORM(10, 10000, RANDOM())::INT END,
    CASE WHEN SEQ4() % 10 = 8 THEN NULL ELSE UNIFORM(1, 1000, RANDOM())::INT * 100000000 END,
    CASE WHEN SEQ4() % 100 < 5 THEN TRUE ELSE FALSE END,
    ARRAY_CONSTRUCT('東京都', '大阪府', '神奈川県', '愛知県', '福岡県', '北海道', '埼玉県', '千葉県', '兵庫県', '京都府')[UNIFORM(0, 9, RANDOM())::INT]
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- 4.6 FACT_LOAN_DETAIL（3000件）
INSERT INTO FACT_LOAN_DETAIL (LOAN_NUMBER, COUNTERPARTY_KEY, PRODUCT_KEY, DEPARTMENT_KEY, RATING_KEY, BASE_DATE, LOAN_START_DATE, LOAN_MATURITY_DATE, ORIGINAL_AMOUNT, OUTSTANDING_AMOUNT, UNDRAWN_AMOUNT, INTEREST_RATE, COLLATERAL_TYPE, COLLATERAL_VALUE, GUARANTEE_TYPE, GUARANTEE_VALUE, EXPOSURE_CLASS)
SELECT
    'LN' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    UNIFORM(1, 500, RANDOM())::INT,
    UNIFORM(1, 30, RANDOM())::INT,
    UNIFORM(1, 13, RANDOM())::INT,
    UNIFORM(1, 12, RANDOM())::INT,
    CURRENT_DATE(),
    DATEADD('day', -UNIFORM(30, 3650, RANDOM())::INT, CURRENT_DATE()),
    DATEADD('day', UNIFORM(30, 3650, RANDOM())::INT, CURRENT_DATE()),
    UNIFORM(1, 100, RANDOM())::INT * 10000000,
    UNIFORM(1, 80, RANDOM())::INT * 10000000,
    CASE WHEN UNIFORM(0, 10, RANDOM()) < 3 THEN UNIFORM(1, 20, RANDOM())::INT * 10000000 ELSE 0 END,
    UNIFORM(5, 300, RANDOM())::NUMBER / 10000,
    CASE UNIFORM(0, 4, RANDOM())::INT 
        WHEN 0 THEN '不動産'
        WHEN 1 THEN '有価証券'
        WHEN 2 THEN '預金'
        WHEN 3 THEN '動産'
        ELSE 'なし'
    END,
    CASE WHEN UNIFORM(0, 10, RANDOM()) < 5 THEN UNIFORM(1, 50, RANDOM())::INT * 10000000 ELSE 0 END,
    CASE UNIFORM(0, 3, RANDOM())::INT
        WHEN 0 THEN '信用保証協会'
        WHEN 1 THEN '保証会社'
        WHEN 2 THEN '個人保証'
        ELSE 'なし'
    END,
    CASE WHEN UNIFORM(0, 10, RANDOM()) < 4 THEN UNIFORM(1, 30, RANDOM())::INT * 10000000 ELSE 0 END,
    CASE UNIFORM(0, 5, RANDOM())::INT
        WHEN 0 THEN '事業法人'
        WHEN 1 THEN 'リテール（居住用不動産）'
        WHEN 2 THEN 'リテール（その他）'
        WHEN 3 THEN '中小企業'
        WHEN 4 THEN '金融機関'
        ELSE '事業法人'
    END
FROM TABLE(GENERATOR(ROWCOUNT => 3000));

-- 4.7 FACT_INTERNAL_RISK（3000件）
INSERT INTO FACT_INTERNAL_RISK (LOAN_KEY, BASE_DATE, EAD, PD, LGD, MATURITY_YEARS, EL, UL, ECONOMIC_CAPITAL, RISK_CONTRIBUTION, CALCULATION_METHOD)
SELECT
    L.LOAN_KEY,
    L.BASE_DATE,
    L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * 0.75),
    R.PD_CENTRAL,
    CASE 
        WHEN L.COLLATERAL_TYPE = '不動産' THEN 0.35
        WHEN L.COLLATERAL_TYPE = '有価証券' THEN 0.30
        WHEN L.COLLATERAL_TYPE = '預金' THEN 0.10
        WHEN L.GUARANTEE_TYPE = '信用保証協会' THEN 0.25
        ELSE 0.45
    END,
    DATEDIFF('day', L.BASE_DATE, L.LOAN_MATURITY_DATE) / 365.0,
    (L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * 0.75)) * R.PD_CENTRAL * 
        CASE 
            WHEN L.COLLATERAL_TYPE = '不動産' THEN 0.35
            WHEN L.COLLATERAL_TYPE = '有価証券' THEN 0.30
            WHEN L.COLLATERAL_TYPE = '預金' THEN 0.10
            WHEN L.GUARANTEE_TYPE = '信用保証協会' THEN 0.25
            ELSE 0.45
        END,
    (L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * 0.75)) * SQRT(R.PD_CENTRAL * (1 - R.PD_CENTRAL)) * 2.33 *
        CASE 
            WHEN L.COLLATERAL_TYPE = '不動産' THEN 0.35
            WHEN L.COLLATERAL_TYPE = '有価証券' THEN 0.30
            WHEN L.COLLATERAL_TYPE = '預金' THEN 0.10
            WHEN L.GUARANTEE_TYPE = '信用保証協会' THEN 0.25
            ELSE 0.45
        END,
    (L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * 0.75)) * R.PD_CENTRAL * 0.08,
    (L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * 0.75)) * R.PD_CENTRAL * 0.01,
    '内部モデル'
FROM FACT_LOAN_DETAIL L
JOIN DIM_RATING R ON L.RATING_KEY = R.RATING_KEY;

-- 4.8 FACT_REGULATORY_RISK（3000件）
INSERT INTO FACT_REGULATORY_RISK (LOAN_KEY, BASE_DATE, EAD, RISK_WEIGHT, RWA, EXPOSURE_CLASS_REGULATORY, APPROACH_TYPE, CRM_TYPE, CRM_VALUE, K_IRB, SCALING_FACTOR)
SELECT
    L.LOAN_KEY,
    L.BASE_DATE,
    L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * P.CCF),
    CASE L.EXPOSURE_CLASS
        WHEN 'ソブリン' THEN 0.00
        WHEN '金融機関' THEN 0.20
        WHEN 'リテール（居住用不動産）' THEN 0.35
        WHEN 'リテール（その他）' THEN 0.75
        WHEN '中小企業' THEN 0.75
        ELSE LEAST(1.50, GREATEST(0.20, R.PD_CENTRAL * 12.5))
    END,
    (L.OUTSTANDING_AMOUNT + (L.UNDRAWN_AMOUNT * P.CCF)) * 
        CASE L.EXPOSURE_CLASS
            WHEN 'ソブリン' THEN 0.00
            WHEN '金融機関' THEN 0.20
            WHEN 'リテール（居住用不動産）' THEN 0.35
            WHEN 'リテール（その他）' THEN 0.75
            WHEN '中小企業' THEN 0.75
            ELSE LEAST(1.50, GREATEST(0.20, R.PD_CENTRAL * 12.5))
        END,
    L.EXPOSURE_CLASS,
    CASE 
        WHEN L.EXPOSURE_CLASS IN ('事業法人', '中小企業') THEN '基礎的内部格付手法'
        WHEN L.EXPOSURE_CLASS LIKE 'リテール%' THEN '先進的内部格付手法'
        ELSE '標準的手法'
    END,
    CASE 
        WHEN L.COLLATERAL_VALUE > 0 THEN '適格担保'
        WHEN L.GUARANTEE_VALUE > 0 THEN '適格保証'
        ELSE 'なし'
    END,
    L.COLLATERAL_VALUE + L.GUARANTEE_VALUE,
    R.PD_CENTRAL * 0.08,
    1.06
FROM FACT_LOAN_DETAIL L
JOIN DIM_RATING R ON L.RATING_KEY = R.RATING_KEY
JOIN DIM_PRODUCT P ON L.PRODUCT_KEY = P.PRODUCT_KEY;

-- 4.9 RISK_DOCUMENT（40件）
INSERT INTO RISK_DOCUMENT (DOCUMENT_ID, TITLE, CONTENT, DOCUMENT_TYPE, CATEGORY, KEYWORDS)
VALUES
-- リスク管理規程
('DOC001', '信用リスク管理方針', '【信用リスク管理方針】

1. 基本方針
当行は、信用リスクを「信用供与先の財務状況の悪化等により、資産の価値が減少ないし消失し、損失を被るリスク」と定義し、適切な管理態勢のもとで統合的にリスク管理を行います。

2. 管理態勢
・取締役会は、信用リスク管理の基本方針を決定し、管理態勢を整備します。
・リスク管理委員会は、信用リスクの状況をモニタリングし、必要な対応策を審議します。
・リスク管理部は、信用リスクの計測・分析・報告を担当します。

3. 信用リスクの計測
・内部格付制度に基づきPD（デフォルト確率）を推計します。
・LGD（デフォルト時損失率）、EAD（デフォルト時エクスポージャー）を算出します。
・EL（期待損失）= EAD × PD × LGD として計算します。
・UL（非期待損失）はVaR手法により算出します。

4. 与信限度額管理
・取引先ごと、グループごと、業種ごとに与信限度額を設定します。
・大口与信については、個別に取締役会の承認を得ます。

5. モニタリング
・日次で与信状況をモニタリングします。
・月次でリスク量の推移を報告します。
・四半期ごとにストレステストを実施します。', '規程', 'リスク管理規程', '信用リスク,方針,管理態勢,EL,UL'),

('DOC002', '信用リスク計量化ルール', '【信用リスク計量化ルール】

1. 対象範囲
本ルールは、当行が保有するすべての信用エクスポージャーに適用します。

2. リスクパラメータの定義
(1) PD（デフォルト確率）
・内部格付に対応するPDを使用します。
・PDの推計は過去10年間のデフォルト実績に基づきます。
・景気循環を考慮したTTC（Through-the-Cycle）PDを採用します。

(2) LGD（デフォルト時損失率）
・担保種類ごとに標準LGDを設定します。
  - 不動産担保: 35%
  - 有価証券担保: 30%
  - 預金担保: 10%
  - 信用保証協会保証: 25%
  - 無担保: 45%

(3) EAD（デフォルト時エクスポージャー）
・オンバランス項目: 帳簿価額
・オフバランス項目: 名目金額 × CCF（掛目）
  - コミットメントライン: 75%
  - 保証: 100%
  - 履行保証: 50%

3. 計算式
EL = Σ（EAD × PD × LGD）
UL = VaR（99.9%信頼区間） - EL', '規程', 'リスク管理規程', '計量化,PD,LGD,EAD,計算式'),

('DOC003', '格付制度運用細則', '【格付制度運用細則】

1. 内部格付の体系
・事業法人向け: 15段階（1～15）
・リテール向け: プール方式
・ソブリン・金融機関向け: 外部格付準拠

2. 格付付与プロセス
(1) 初回格付
・新規取引開始時に財務データ、定性評価に基づき格付を付与します。
・審査部による二次審査を経て確定します。

(2) 定期見直し
・年1回の定期見直しを実施します。
・決算期到来から3ヶ月以内に見直しを完了します。

(3) 随時見直し
・格付見直しトリガー事由が発生した場合、速やかに見直します。
・トリガー事由: 延滞発生、業績悪化、信用事象等

3. 格付と外部格付の対応
格付1-2: AAA/AA
格付3-4: A
格付5-6: BBB
格付7-8: BB
格付9-10: B
格付11以下: CCC以下', '規程', 'リスク管理規程', '格付,内部格付,見直し,プロセス'),

('DOC004', '与信限度額管理規程', '【与信限度額管理規程】

1. 目的
本規程は、与信集中リスクを適切に管理し、健全な与信ポートフォリオを維持することを目的とします。

2. 限度額の種類
(1) 取引先限度額
・単一取引先への与信上限を設定します。
・自己資本の10%を上限とします。

(2) グループ限度額
・企業グループへの与信上限を設定します。
・自己資本の15%を上限とします。

(3) 業種限度額
・特定業種への与信上限を設定します。
・業種ごとにリスクアペタイトに基づき設定します。

(4) 国別限度額
・海外向け与信の国別上限を設定します。
・カントリーリスク評価に基づき設定します。

3. 承認権限
・通常与信: 審査部長
・大口与信（限度額の50%超）: 担当役員
・特大口与信（限度額の80%超）: 取締役会', '規程', 'リスク管理規程', '限度額,与信集中,承認権限'),

('DOC005', '大口与信管理要領', '【大口与信管理要領】

1. 大口与信の定義
・自己資本の1%を超える与信を大口与信と定義します。
・グループベースで合算して判定します。

2. 管理態勢
・大口与信先リストを作成し、四半期ごとに更新します。
・大口与信先の信用状況を重点的にモニタリングします。

3. 報告体制
・月次: リスク管理部からリスク管理委員会へ報告
・四半期: 取締役会への報告
・臨時: 信用事象発生時の即時報告

4. 規制対応
・大口エクスポージャー規制に準拠します。
・単一取引先: Tier1資本の25%以内
・銀行グループ向け: Tier1資本の25%以内', '規程', 'リスク管理規程', '大口与信,モニタリング,報告'),

('DOC006', '信用リスク報告体制', '【信用リスク報告体制】

1. 日次報告
・与信残高の異動状況
・延滞発生状況
・格付異動状況

2. 月次報告
(1) リスク管理委員会向け
・ポートフォリオ概況
・格付別・業種別エクスポージャー
・EL/UL推移
・与信限度額使用状況

(2) 経営会議向け
・重要リスク指標のサマリー
・特記事項

3. 四半期報告
・ストレステスト結果
・規制資本（RWA）の状況
・自己資本比率への影響分析

4. 年次報告
・リスクアペタイト達成状況
・格付精度検証（バックテスト）
・モデル検証結果', '規程', 'リスク管理規程', '報告体制,日次,月次,四半期'),

('DOC007', '自己査定実施要領', '【自己査定実施要領】

1. 目的
・資産の健全性を自ら査定し、適切な償却・引当を行います。

2. 債務者区分
(1) 正常先: 業況良好、財務内容に問題なし
(2) 要注意先: 業況低調、財務内容に問題あり
(3) 要管理先: 要注意先のうち、3ヶ月以上延滞または貸出条件緩和
(4) 破綻懸念先: 経営破綻の状況にはないが、経営難で元利返済が滞りがち
(5) 実質破綻先: 法的・形式的破綻ではないが、実質的に経営破綻
(6) 破綻先: 法的・形式的に経営破綻

3. 分類区分
I分類: 回収の危険性なし
II分類: 回収について注意を要する
III分類: 回収に重大な懸念あり、損失の可能性が高い
IV分類: 回収不能または無価値', '規程', 'リスク管理規程', '自己査定,債務者区分,分類'),

('DOC008', '貸倒引当金計上基準', '【貸倒引当金計上基準】

1. 一般貸倒引当金
・正常先債権: 過去の貸倒実績率に基づき計上
・要注意先債権: 過去の貸倒実績率に基づき計上（正常先より高い率）

2. 個別貸倒引当金
・要管理先: 債権額から担保・保証による回収見込額を控除した残額の15%以上
・破綻懸念先: 債権額から担保・保証による回収見込額を控除した残額の70%以上
・実質破綻先・破綻先: 債権額から担保・保証による回収見込額を控除した全額

3. DCF法
・大口の破綻懸念先等については、将来キャッシュフローを割り引いて引当額を算定します。', '規程', 'リスク管理規程', '引当金,貸倒,DCF'),

('DOC009', 'ストレステスト実施要領', '【ストレステスト実施要領】

1. 目的
・経済環境の悪化等のストレス事象が発生した場合の影響を把握します。
・リスク管理の高度化、資本計画への活用を図ります。

2. 実施頻度
・定期: 四半期ごと
・臨時: 重大な経済事象発生時

3. シナリオ
(1) ヒストリカルシナリオ
・リーマンショック時
・バブル崩壊時

(2) 仮想シナリオ
・GDP-3%成長
・不動産価格30%下落
・株価50%下落

4. 影響分析項目
・PDの上昇
・LGDの上昇
・EL/ULの増加
・RWAの増加
・自己資本比率への影響', '規程', 'リスク管理規程', 'ストレステスト,シナリオ,影響分析'),

('DOC010', 'リスクアペタイト方針', '【リスクアペタイト方針】

1. リスクアペタイトとは
・当行が経営目標達成のために進んで取るリスクの種類と量を明確化したものです。

2. 信用リスクに関するリスクアペタイト
(1) リスク量の上限
・経済資本: 自己資本の80%以内
・EL: 年間利益の50%以内

(2) 集中リスクの制限
・大口与信（上位10先）: 総与信の20%以内
・不動産業向け: 総与信の15%以内
・海外向け: 総与信の10%以内

(3) 格付構成の目標
・投資適格（格付8以上）: 80%以上
・要注意先以下: 5%以内

3. モニタリング
・リスクアペタイト指標を月次でモニタリングします。
・閾値超過時はリスク管理委員会へエスカレーションします。', '規程', 'リスク管理規程', 'リスクアペタイト,経済資本,集中リスク'),

-- バーゼル規制解説
('DOC011', 'バーゼルIII概要', '【バーゼルIII概要】

1. 背景
・2008年の金融危機を受けて、銀行規制の強化が図られました。
・バーゼルIIIは2010年に合意され、段階的に導入されています。

2. 三つの柱
第一の柱（最低所要自己資本）
・信用リスク、市場リスク、オペレーショナルリスクに対する資本賦課

第二の柱（監督上の検証）
・銀行の自己資本充実度評価プロセス（ICAAP）
・監督当局による検証

第三の柱（市場規律）
・開示規制による市場規律の活用

3. 自己資本比率規制
・普通株式等Tier1比率: 4.5%以上
・Tier1比率: 6%以上
・総自己資本比率: 8%以上
・資本保全バッファー: 2.5%
・カウンターシクリカルバッファー: 0-2.5%', '解説', 'バーゼル規制', 'バーゼルIII,自己資本比率,三つの柱'),

('DOC012', '信用リスクの標準的手法', '【信用リスクの標準的手法】

1. 概要
・外部格付や資産の種類に応じて、予め定められたリスクウェイトを適用する手法です。
・IRB手法の承認を得ていない銀行が使用します。

2. エクスポージャー区分とリスクウェイト
(1) ソブリン向け
・外部格付AAA～AA: 0%
・外部格付A: 20%
・外部格付BBB: 50%
・外部格付BB以下: 100-150%

(2) 金融機関向け
・外部格付AAA～AA: 20%
・外部格付A: 50%
・外部格付BBB～BB: 100%
・外部格付B以下: 150%

(3) 事業法人向け
・外部格付AAA～AA: 20%
・外部格付A: 50%
・外部格付BBB～BB: 100%
・外部格付B以下: 150%
・格付なし: 100%

(4) リテール向け
・住宅ローン: 35%
・その他: 75%', '解説', 'バーゼル規制', '標準的手法,リスクウェイト,エクスポージャー'),

('DOC013', '信用リスクの内部格付手法（IRB）', '【信用リスクの内部格付手法（IRB）】

1. 概要
・銀行が内部格付システムを用いてPDを推計し、リスクウェイトを算出する手法です。
・監督当局の承認が必要です。

2. 基礎的内部格付手法（FIRB）
・銀行がPDを推計
・LGD、EAD、Mは監督当局が定める値を使用
・LGD: 担保付45%、無担保45%（軽減後）
・M: 2.5年

3. 先進的内部格付手法（AIRB）
・銀行がPD、LGD、EAD、Mをすべて推計
・より精緻なリスク計測が可能
・データ要件、検証要件が厳格

4. リスクウェイト関数
K = [LGD × N[(1-R)^(-0.5) × G(PD) + (R/(1-R))^0.5 × G(0.999)] - PD × LGD] × (1-1.5×b)^(-1) × (1+(M-2.5)×b)
RW = K × 12.5 × EAD

※N: 標準正規分布の累積分布関数
※G: 標準正規分布の逆関数
※R: 相関係数
※b: 満期調整係数', '解説', 'バーゼル規制', 'IRB,内部格付,FIRB,AIRB'),

('DOC014', 'リスクウェイト算出方法', '【リスクウェイト算出方法】

1. 標準的手法
RWA = Σ（エクスポージャー × 所定のリスクウェイト）

2. IRB手法（事業法人向け）
(1) 相関係数R
R = 0.12 × (1-EXP(-50×PD))/(1-EXP(-50)) + 0.24 × [1-(1-EXP(-50×PD))/(1-EXP(-50))]
※中小企業向けは売上高に応じて軽減

(2) 満期調整係数b
b = [0.11852 - 0.05478 × ln(PD)]^2

(3) 所要自己資本K
K = [LGD × N[(1-R)^(-0.5) × G(PD) + (R/(1-R))^0.5 × G(0.999)] - PD × LGD] × (1-1.5×b)^(-1) × (1+(M-2.5)×b)

(4) リスクウェイト
RW = K × 12.5

(5) RWA
RWA = RW × EAD × 1.06（スケーリングファクター）', '解説', 'バーゼル規制', 'リスクウェイト,計算式,IRB'),

('DOC015', '信用リスク削減手法（CRM）', '【信用リスク削減手法（CRM）】

1. 概要
・担保や保証によりリスクを軽減する手法です。
・適格要件を満たす必要があります。

2. 適格担保
(1) 金融資産担保
・現金、預金
・政府・中央銀行発行証券
・上場株式（ヘアカット適用）

(2) 不動産担保
・居住用不動産: LTV60%以内、LGD軽減
・商業用不動産: LTV60%以内、LGD軽減

3. 適格保証
・ソブリン、金融機関、格付BBB-以上の事業法人
・保証の法的有効性が必要
・代位弁済条件の明確化

4. CRMの効果
・包括的手法: エクスポージャーを担保価値分減額
・簡便手法: リスクウェイトを保証人のリスクウェイトに置換', '解説', 'バーゼル規制', 'CRM,担保,保証,適格'),

('DOC016', 'エクスポージャー区分の定義', '【エクスポージャー区分の定義】

1. ソブリン向け
・中央政府、中央銀行
・国際機関、国際開発銀行

2. 金融機関向け
・銀行、証券会社、保険会社
・規制を受ける金融機関

3. 事業法人向け
・上記以外の法人向けエクスポージャー
・売上高50億円超の企業

4. 中小企業向け
・事業法人のうち、売上高50億円以下
・年間売上高に応じて相関係数を軽減

5. リテール向け
(1) 居住用不動産
・個人向け住宅ローン
・LTV制限あり

(2) 適格リボルビング
・カードローン等
・限度額1億円以下

(3) その他リテール
・上記以外の個人向けエクスポージャー
・1億円以下

6. 株式等エクスポージャー
・上場株式、非上場株式
・投資ファンド出資', '解説', 'バーゼル規制', 'エクスポージャー,区分,定義'),

('DOC017', 'PD/LGD/EADの定義と計算', '【PD/LGD/EADの定義と計算】

1. PD（デフォルト確率）
(1) 定義
・1年以内にデフォルトする確率
・格付ごとに設定

(2) デフォルトの定義
・90日以上の延滞
・債務不履行の蓋然性が高い
・破産手続き開始

(3) 推計方法
・内部デフォルト実績に基づく
・最低5年間のデータ
・景気循環を考慮

2. LGD（デフォルト時損失率）
(1) 定義
・デフォルト時の損失額 / EAD
・担保、保証を考慮

(2) FIRB標準値
・優先債権（無担保）: 45%
・劣後債権: 75%

3. EAD（デフォルト時エクスポージャー）
(1) オンバランス
・帳簿価額を使用

(2) オフバランス
・EAD = コミット額 × CCF
・コミットメント: CCF 75%
・保証: CCF 100%', '解説', 'バーゼル規制', 'PD,LGD,EAD,推計'),

('DOC018', '期待損失（EL）と非期待損失（UL）', '【期待損失（EL）と非期待損失（UL）】

1. 期待損失（EL）
(1) 定義
・平均的に発生すると予想される損失
・引当金でカバー

(2) 計算式
EL = EAD × PD × LGD

(3) 特徴
・ポートフォリオの期待値
・会計上の引当金に対応
・収益で吸収すべき損失

2. 非期待損失（UL）
(1) 定義
・ELを超える予想外の損失
・自己資本でカバー

(2) 計算方法
・信頼区間（99.9%等）での最大損失 - EL
・VaR手法で計算

(3) 特徴
・損失分布の裾リスク
・規制資本で対応
・経済資本の基礎

3. EL/ULと資本の関係
・EL ≦ 引当金: 超過分はTier2に算入可
・EL > 引当金: 不足分はTier1から控除
・UL: 所要自己資本として賦課', '解説', 'バーゼル規制', 'EL,UL,期待損失,非期待損失'),

('DOC019', '自己資本比率規制', '【自己資本比率規制】

1. 自己資本比率の計算
自己資本比率 = 自己資本 / リスクアセット

2. 所要水準
(1) 最低基準
・普通株式等Tier1比率: 4.5%
・Tier1比率: 6.0%
・総自己資本比率: 8.0%

(2) 資本バッファー
・資本保全バッファー: 2.5%
・カウンターシクリカルバッファー: 0-2.5%
・G-SIBサーチャージ: 1-3.5%
・D-SIBサーチャージ: 0.5-2%

3. 自己資本の構成
(1) 普通株式等Tier1
・普通株式
・利益剰余金
・その他の包括利益累計額

(2) その他Tier1
・優先株式
・永久劣後債

(3) Tier2
・劣後債
・一般貸倒引当金（標準的手法）

4. 調整項目
・のれん、無形資産
・繰延税金資産
・金融機関向け出資', '解説', 'バーゼル規制', '自己資本比率,Tier1,バッファー'),

('DOC020', 'レバレッジ比率規制', '【レバレッジ比率規制】

1. 目的
・リスクベースの自己資本比率を補完
・過度なレバレッジの抑制

2. 計算式
レバレッジ比率 = Tier1資本 / エクスポージャー

3. 所要水準
・最低基準: 3%
・G-SIB追加: 0.5-1%

4. エクスポージャーの範囲
(1) オンバランス項目
・会計上の資産（ネッティング前）

(2) デリバティブ
・再構築コスト + 潜在的エクスポージャー

(3) SFT（有価証券金融取引）
・レポ取引、有価証券貸借取引

(4) オフバランス項目
・コミットメント等に10-100%のCCF適用

5. 日本の対応
・2019年3月より適用
・国際統一基準行: 3%
・国内基準行: 対象外', '解説', 'バーゼル規制', 'レバレッジ比率,Tier1,規制'),

('DOC021', '大口エクスポージャー規制', '【大口エクスポージャー規制】

1. 目的
・与信集中リスクの制限
・システミックリスクの抑制

2. 規制の概要
(1) 単一取引先
・Tier1資本の25%以内

(2) 銀行グループ向け（G-SIB）
・Tier1資本の15%以内

3. エクスポージャーの範囲
・貸出、コミットメント
・デリバティブ取引
・有価証券投資
・保証、信用状

4. グループ集約
・経済的相互依存関係がある場合、合算
・支配関係がある場合、合算

5. 報告義務
・Tier1資本の10%超: 四半期報告
・限度額超過: 即時報告

6. 適用除外
・ソブリン向け（自国通貨建て）
・決済機関向け（日中）
・清算機関向け', '解説', 'バーゼル規制', '大口エクスポージャー,集中リスク,Tier1'),

('DOC022', 'カウンターパーティ信用リスク', '【カウンターパーティ信用リスク】

1. 定義
・デリバティブ取引、SFT等において、取引相手方がデフォルトすることによるリスク

2. エクスポージャーの計算
(1) カレントエクスポージャー方式
・EAD = max(時価, 0) + 想定元本 × アドオン

(2) SA-CCR（標準的手法）
・EAD = α × (RC + PFE)
・α = 1.4
・RC: 再構築コスト
・PFE: 潜在的将来エクスポージャー

3. CVAリスク
・CVA（信用評価調整）の変動リスク
・標準的手法または内部モデル手法

4. リスク削減
・法的に有効なネッティング
・適格担保の受入れ
・CCP（中央清算機関）の活用', '解説', 'バーゼル規制', 'カウンターパーティ,デリバティブ,CVA'),

('DOC023', 'CVA（信用評価調整）リスク', '【CVA（信用評価調整）リスク】

1. CVAとは
・デリバティブ取引の時価評価において、取引相手方の信用リスクを反映した調整

2. 計算式
CVA = (1-回収率) × Σ[デフォルト確率 × 期待エクスポージャー × 割引係数]

3. CVAリスクの資本賦課
(1) 標準的手法
・エクスポージャーと信用スプレッドに基づく計算

(2) 基礎的CVA手法
・ヘッジ効果を一部認識

(3) 先進的CVA手法（SA-CVA）
・感応度に基づくリスク計測
・より精緻なヘッジ認識

4. 適用除外
・非金融事業法人との取引
・年金基金との取引
・SFT取引（CVAリスクが軽微な場合）', '解説', 'バーゼル規制', 'CVA,信用評価調整,デリバティブ'),

('DOC024', '開示規制（Pillar 3）', '【開示規制（Pillar 3）】

1. 目的
・市場参加者による銀行のリスクプロファイル評価を可能にする
・市場規律による健全性確保

2. 開示項目
(1) 自己資本の構成
・Tier1、Tier2の内訳
・調整項目の詳細

(2) 信用リスク
・エクスポージャー区分別残高
・格付区分別残高
・地域別、業種別残高
・延滞・減損状況

(3) 信用リスク削減
・担保の種類、金額
・保証の状況
・ネッティングの効果

(4) 規制資本
・RWAの内訳
・自己資本比率の計算過程

3. 開示頻度
・年次: 詳細開示
・半期: 主要項目
・四半期: 要約情報', '解説', 'バーゼル規制', 'Pillar3,開示,ディスクロージャー'),

('DOC025', 'バーゼルIIIファイナライズ', '【バーゼルIIIファイナライズ】

1. 概要
・2017年12月に最終合意
・2023年以降段階的に導入（日本は2024年3月～）

2. 主な変更点
(1) 標準的手法の見直し
・リスクウェイトの細分化
・外部格付への依存軽減

(2) IRB手法の制限
・LGD、EADのインプットフロア導入
・特定エクスポージャーへのIRB使用制限

(3) アウトプットフロア
・IRB手法のRWAが標準的手法の72.5%を下回らない

(4) オペレーショナルリスク
・新標準的手法への一本化

(5) CVAリスク
・新たな標準的手法の導入

3. 移行期間
・2024年から段階的導入
・2028年に完全適用
・アウトプットフロア: 50%から72.5%へ段階的引上げ', '解説', 'バーゼル規制', 'ファイナライズ,アウトプットフロア,2024'),

-- 業務マニュアル
('DOC026', '月次リスクレポート作成手順', '【月次リスクレポート作成手順】

1. 作成スケジュール
・月末基準日の翌営業日5日目までに完成
・リスク管理委員会（月末+10営業日）へ報告

2. データ収集
(1) 必要データ
・月末時点の与信残高
・格付情報
・担保・保証情報
・部門情報

(2) データ抽出
・基幹システムからの自動連携
・データ検証（前月比チェック）

3. レポート項目
(1) エグゼクティブサマリー
・ポートフォリオ概況
・主要リスク指標
・特記事項

(2) 詳細分析
・格付別エクスポージャー
・業種別エクスポージャー
・部門別エクスポージャー
・EL/UL推移
・RWA推移

(3) 限度額管理
・大口与信状況
・業種限度額使用状況

4. 承認フロー
・リスク管理部長 → 担当役員 → リスク管理委員会', 'マニュアル', '業務マニュアル', '月次レポート,作成手順,報告'),

('DOC027', '日次リスクモニタリング手順', '【日次リスクモニタリング手順】

1. モニタリング項目
(1) 与信異動
・新規実行、期限到来、中途返済
・大口与信の異動

(2) 延滞状況
・新規延滞発生
・延滞解消
・延滞長期化

(3) 格付変動
・格下げ、格上げ
・要注意先以下への遷移

(4) 限度額
・限度額超過先の有無
・限度額接近先

2. アラート基準
・5億円以上の新規延滞: 即時報告
・大口先の格下げ: 即時報告
・限度額超過: 即時報告

3. 報告
・日次報告書の作成
・異常事象は即時エスカレーション', 'マニュアル', '業務マニュアル', '日次モニタリング,延滞,アラート'),

('DOC028', '格付見直しプロセス', '【格付見直しプロセス】

1. 定期見直し
(1) トリガー
・決算期到来
・年次見直し時期到来

(2) プロセス
・営業部門による格付申請
・審査部による財務分析
・格付判定会議での審議
・格付確定、システム登録

(3) 期限
・決算期到来後3ヶ月以内

2. 随時見直し
(1) トリガー事由
・延滞発生（30日以上）
・条件変更申請
・業績大幅悪化
・信用事象の発生
・外部格付変動

(2) プロセス
・事象発生後速やかに見直し着手
・緊急格付判定会議の開催
・格付確定、システム登録

3. 承認権限
・格上げ: 審査部長
・格据置: 審査課長
・格下げ: 審査部長（2ノッチ以上は担当役員）', 'マニュアル', '業務マニュアル', '格付見直し,定期,随時'),

('DOC029', '異常値検知対応フロー', '【異常値検知対応フロー】

1. 異常値の定義
・前月比30%以上の変動
・過去平均から3σ以上の乖離
・論理的に矛盾するデータ

2. 検知方法
・システムによる自動検知
・担当者による目視チェック
・月次データ確定時のバリデーション

3. 対応フロー
(1) 検知時
・異常値フラグの付与
・担当者への通知

(2) 原因調査
・データソースの確認
・入力誤り、システム障害の有無
・業務上の正当な理由の有無

(3) 対応
・データ修正（承認付き）
・正当事由の場合は記録を残す
・システム障害の場合はIT部門へ連絡

(4) 報告
・重大な異常は上位者へ報告
・再発防止策の検討', 'マニュアル', '業務マニュアル', '異常値,検知,データ品質'),

('DOC030', 'データ品質管理ルール', '【データ品質管理ルール】

1. データ品質の定義
(1) 正確性
・入力データが事実と一致
・計算結果が正しい

(2) 完全性
・必要なデータが全て存在
・欠損がない

(3) 適時性
・期限内にデータが更新
・最新状態が維持

(4) 一貫性
・システム間でデータが整合
・定義が統一

2. 品質管理プロセス
(1) 入力時チェック
・必須項目の入力チェック
・範囲チェック、論理チェック

(2) 日次検証
・整合性チェック
・前日比チェック

(3) 月次検証
・網羅性チェック
・他システムとの照合

3. 問題発生時の対応
・影響範囲の特定
・原因分析
・修正、再計算
・再発防止策の実施', 'マニュアル', '業務マニュアル', 'データ品質,正確性,完全性'),

('DOC031', 'システム間データ連携仕様', '【システム間データ連携仕様】

1. 連携元システム
(1) 勘定系システム
・貸出金明細
・入出金情報
・利息計算情報

(2) 情報系システム
・取引先マスタ
・格付情報
・担保情報

2. 連携方式
・日次バッチ連携（深夜）
・リアルタイム連携（重要取引）

3. データフォーマット
・CSVファイル（バッチ）
・API（リアルタイム）

4. 連携項目
(1) 貸出金明細
・貸出番号、取引先コード
・商品コード、部門コード
・残高、金利、期日

(2) 取引先情報
・取引先コード、名称
・格付、業種
・財務情報

5. エラーハンドリング
・連携失敗時の再処理
・整合性エラー時の対応', 'マニュアル', '業務マニュアル', 'データ連携,システム,バッチ'),

('DOC032', '部門別配賦計算方法', '【部門別配賦計算方法】

1. 配賦の目的
・リスク量を部門別に把握
・リスクに見合ったリターンの評価
・部門業績評価への活用

2. 配賦対象
・信用リスクアセット（RWA）
・期待損失（EL）
・経済資本

3. 配賦ルール
(1) 直接配賦
・取引ごとに担当部門を特定
・担当部門に直接配賦

(2) 案分配賦
・複数部門が関与する場合
・貢献度に応じて案分

4. 計算方法
・部門別RWA = Σ（案件別RWA × 部門配賦率）
・部門別EL = Σ（案件別EL × 部門配賦率）

5. 配賦結果の活用
・部門別収益性分析
・RAROC（リスク調整後収益率）計算
・部門予算への反映', 'マニュアル', '業務マニュアル', '配賦,部門別,RAROC'),

('DOC033', '経営報告資料作成ガイド', '【経営報告資料作成ガイド】

1. 報告体系
(1) 取締役会
・四半期：リスク状況報告
・年次：リスク管理態勢報告

(2) リスク管理委員会
・月次：リスクモニタリング報告
・四半期：ストレステスト報告

(3) 経営会議
・月次：主要リスク指標報告

2. 資料構成
(1) エグゼクティブサマリー
・1-2ページ
・主要指標と前期比較
・重要事項のハイライト

(2) 詳細分析
・ポートフォリオ分析
・リスク量推移
・限度額管理状況

(3) アクションプラン
・課題と対応策
・今後の見通し

3. 作成上の留意点
・グラフ、表を活用し視認性向上
・前期比較、計画比を明示
・重要事項は冒頭で説明', 'マニュアル', '業務マニュアル', '経営報告,取締役会,資料作成'),

('DOC034', '監査対応準備チェックリスト', '【監査対応準備チェックリスト】

1. 内部監査対応
□ リスク管理規程の最新版を準備
□ 月次レポートの過去1年分を整理
□ 格付判定会議議事録を準備
□ 限度額超過対応記録を準備
□ 異常値対応記録を準備

2. 外部監査対応
□ 自己査定関連資料を準備
□ 引当金計算根拠を準備
□ 格付モデル検証資料を準備
□ バックテスト結果を準備

3. 当局検査対応
□ 規程類の整備状況を確認
□ 取締役会等への報告資料を準備
□ リスクアペタイト関連資料を準備
□ ストレステスト関連資料を準備
□ 大口与信管理資料を準備

4. 資料管理
・電子ファイルの格納場所を統一
・資料一覧表を作成
・版管理を徹底', 'マニュアル', '業務マニュアル', '監査対応,チェックリスト,準備'),

('DOC035', 'BCP対応手順（リスク管理）', '【BCP対応手順（リスク管理）】

1. 災害発生時の対応
(1) 初動対応
・要員の安否確認
・システム稼働状況の確認
・代替拠点への移動

(2) 業務継続
・重要業務の特定と優先順位
・最低限必要なリスク管理業務の継続

2. 重要業務
(1) 優先度A（即時再開）
・大口与信のモニタリング
・延滞発生の把握
・緊急の格付変更

(2) 優先度B（3日以内再開）
・日次リスクモニタリング
・システム連携の復旧

(3) 優先度C（1週間以内再開）
・月次レポート作成
・通常業務の完全復旧

3. 代替手段
・手作業による計算
・簡易的なリスク把握
・本部への電話報告

4. 訓練
・年1回のBCP訓練実施
・訓練結果の検証と改善', 'マニュアル', '業務マニュアル', 'BCP,災害対応,業務継続'),

-- 用語集・参照資料
('DOC036', '信用リスク用語集', '【信用リスク用語集】

【あ行】
・アウトプットフロア: IRB手法のRWAが標準的手法の一定割合を下回らないよう設ける下限
・EAD（デフォルト時エクスポージャー）: デフォルト発生時点での与信残高の推計値

【か行】
・格付: 債務者の信用力を段階的に評価したもの
・カウンターパーティリスク: デリバティブ取引等における取引相手方の信用リスク
・期待損失（EL）: 平均的に発生すると予想される損失

【さ行】
・自己資本比率: 自己資本をリスクアセットで除した比率
・信用リスク: 与信先の財務状況悪化等により損失を被るリスク
・ストレステスト: 異常事態を想定したリスク分析

【た行】
・担保: 債権保全のために徴求する資産
・デフォルト: 債務不履行

【は行】
・PD（デフォルト確率）: 1年以内にデフォルトする確率
・非期待損失（UL）: 期待損失を超える予想外の損失

【ま行】
・マチュリティ: 残存期間

【ら行】
・リスクウェイト: 資本賦課の掛目
・リスクアセット: リスク量を資本換算した値
・LGD（デフォルト時損失率）: デフォルト時の損失割合', '参照', '用語集', '用語,定義,信用リスク'),

('DOC037', '金融庁告示早見表', '【金融庁告示早見表】

1. 自己資本比率規制関連
・告示第19号: 自己資本比率規制（国際統一基準）
・告示第20号: 自己資本比率規制（国内基準）
・告示第21号: 連結自己資本比率規制

2. 信用リスク関連条項
第4条: 信用リスクアセットの計算
第5条: 標準的手法
第6条: 内部格付手法
第7条: 信用リスク削減手法
第8条: 証券化エクスポージャー

3. 主要な定義
・エクスポージャー: 第3条
・デフォルトの定義: 第6条第3項
・適格担保: 第7条第2項
・適格保証: 第7条第3項

4. リスクウェイト表
・標準的手法: 別表第1
・IRB手法: 別表第2

5. 参考
・金融庁HP「自己資本比率規制」
・日本銀行「バーゼル規制関連」', '参照', '参照資料', '金融庁,告示,規制'),

('DOC038', '日銀業種分類対応表', '【日銀業種分類対応表】

01 政府
02 地方公共団体
03 政府関係機関
04 農林水産業
05 鉱業・採石業・砂利採取業、電気・ガス・熱供給・水道業
06 建設業
07 繊維工業
08 木材・木製品製造業、パルプ・紙・紙加工品製造業
09 食料品製造業
10 化学工業
11 鉄鋼業
12 非鉄金属製造業
13 金属製品製造業
14 はん用・生産用・業務用機械製造業
15 電気機械器具製造業、情報通信機械器具製造業
16 輸送用機械器具製造業
17 その他の製造業
18 卸売業
19 小売業
20 不動産業
21 物品賃貸業
22 運輸業、郵便業
23 情報通信業
24 金融業、保険業
25 宿泊業、飲食サービス業
26 生活関連サービス業、娯楽業
27 医療、福祉
28 その他のサービス
29 個人
30 海外', '参照', '参照資料', '業種分類,日銀,コード'),

('DOC039', '外部格付対応表', '【外部格付対応表】

| 内部格付 | S&P | Moodys | Fitch | R&I | JCR |
|---------|-----|--------|-------|-----|-----|
| 1 | AAA | Aaa | AAA | AAA | AAA |
| 2 | AA+ | Aa1 | AA+ | AA+ | AA+ |
| 3 | AA | Aa2 | AA | AA | AA |
| 4 | AA- | Aa3 | AA- | AA- | AA- |
| 5 | A+ | A1 | A+ | A+ | A+ |
| 6 | A | A2 | A | A | A |
| 7 | A- | A3 | A- | A- | A- |
| 8 | BBB+ | Baa1 | BBB+ | BBB+ | BBB+ |
| 9 | BBB | Baa2 | BBB | BBB | BBB |
| 10 | BBB- | Baa3 | BBB- | BBB- | BBB- |
| 11 | BB | Ba2 | BB | BB | BB |
| 12 | B | B2 | B | B | B |
| 13 | CCC | Caa | CCC | CCC | CCC |
| 14 | CC | Ca | CC | CC | CC |
| 15 | D | D | D | D | D |

投資適格: 格付10（BBB-）以上
投機的等級: 格付11（BB）以下', '参照', '参照資料', '外部格付,対応,S&P,Moodys'),

('DOC040', '主要指標計算式一覧', '【主要指標計算式一覧】

1. 期待損失（EL）
EL = EAD × PD × LGD

2. 非期待損失（UL）
UL = EAD × LGD × √(PD × (1-PD)) × Φ^(-1)(0.999)
※Φ^(-1): 標準正規分布の逆関数

3. 経済資本
EC = UL（または VaR - EL）

4. 信用RWA（標準的手法）
RWA = Σ(EAD × RW)

5. 信用RWA（IRB手法）
K = [LGD × N[(1-R)^(-0.5) × G(PD) + (R/(1-R))^0.5 × G(0.999)] - PD × LGD] × (1-1.5×b)^(-1) × (1+(M-2.5)×b)
RWA = K × 12.5 × EAD × 1.06

6. 相関係数R（事業法人）
R = 0.12 × (1-e^(-50×PD))/(1-e^(-50)) + 0.24 × [1-(1-e^(-50×PD))/(1-e^(-50))]

7. 満期調整係数b
b = [0.11852 - 0.05478 × ln(PD)]^2

8. 自己資本比率
CAR = 自己資本 / (信用RWA + 市場RWA + オペRWA)

9. RAROC
RAROC = (収益 - EL - 経費) / 経済資本', '参照', '参照資料', '計算式,EL,RWA,RAROC');

-- =============================================================================
-- 5. Semantic View 作成
-- =============================================================================
USE SCHEMA AI;

-- 5.1 内部リスク分析用 Semantic View
CREATE OR REPLACE SEMANTIC VIEW SV_INTERNAL_RISK_ANALYSIS
  TABLES (
    LOAN AS SNOW_RISK.DATA.FACT_LOAN_DETAIL PRIMARY KEY (LOAN_KEY),
    INTERNAL_RISK AS SNOW_RISK.DATA.FACT_INTERNAL_RISK PRIMARY KEY (INTERNAL_RISK_KEY),
    COUNTERPARTY AS SNOW_RISK.DATA.DIM_COUNTERPARTY PRIMARY KEY (COUNTERPARTY_KEY),
    PRODUCT AS SNOW_RISK.DATA.DIM_PRODUCT PRIMARY KEY (PRODUCT_KEY),
    DEPARTMENT AS SNOW_RISK.DATA.DIM_DEPARTMENT PRIMARY KEY (DEPARTMENT_KEY),
    RATING AS SNOW_RISK.DATA.DIM_RATING PRIMARY KEY (RATING_KEY),
    INDUSTRY AS SNOW_RISK.DATA.DIM_INDUSTRY PRIMARY KEY (INDUSTRY_KEY)
  )
  RELATIONSHIPS (
    INTERNAL_RISK (LOAN_KEY) REFERENCES LOAN,
    LOAN (COUNTERPARTY_KEY) REFERENCES COUNTERPARTY,
    LOAN (PRODUCT_KEY) REFERENCES PRODUCT,
    LOAN (DEPARTMENT_KEY) REFERENCES DEPARTMENT,
    LOAN (RATING_KEY) REFERENCES RATING,
    COUNTERPARTY (INDUSTRY_KEY) REFERENCES INDUSTRY
  )
  FACTS (
    LOAN.OUTSTANDING_AMOUNT AS OUTSTANDING_AMOUNT,
    LOAN.UNDRAWN_AMOUNT AS UNDRAWN_AMOUNT,
    LOAN.COLLATERAL_VALUE AS COLLATERAL_VALUE,
    INTERNAL_RISK.EAD AS EAD,
    INTERNAL_RISK.PD AS PD,
    INTERNAL_RISK.LGD AS LGD,
    INTERNAL_RISK.EL_AMOUNT AS EL_AMOUNT,
    INTERNAL_RISK.UL_AMOUNT AS UL_AMOUNT,
    INTERNAL_RISK.ECONOMIC_CAPITAL AS ECONOMIC_CAPITAL
  )
  DIMENSIONS (
    COUNTERPARTY.CP_NAME AS COUNTERPARTY_NAME,
    COUNTERPARTY.CP_TYPE AS COUNTERPARTY_TYPE,
    RATING.RATING_NAME AS RATING_NAME,
    RATING.PD_CENTRAL AS RATING_PD,
    INDUSTRY.INDUSTRY_NAME AS INDUSTRY_NAME,
    DEPARTMENT.DEPARTMENT_NAME AS DEPARTMENT_NAME,
    PRODUCT.PRODUCT_NAME AS PRODUCT_NAME,
    INTERNAL_RISK.BASE_DATE AS BASE_DATE
  )
  METRICS (
    INTERNAL_RISK.TOTAL_EL AS SUM(INTERNAL_RISK.EL_AMOUNT),
    INTERNAL_RISK.TOTAL_UL AS SUM(INTERNAL_RISK.UL_AMOUNT),
    INTERNAL_RISK.TOTAL_EC AS SUM(INTERNAL_RISK.ECONOMIC_CAPITAL),
    INTERNAL_RISK.TOTAL_EAD AS SUM(INTERNAL_RISK.EAD),
    INTERNAL_RISK.AVG_PD AS AVG(INTERNAL_RISK.PD),
    INTERNAL_RISK.AVG_LGD AS AVG(INTERNAL_RISK.LGD),
    LOAN.TOTAL_OUTSTANDING AS SUM(LOAN.OUTSTANDING_AMOUNT)
  );

-- 5.2 規制資本分析用 Semantic View
CREATE OR REPLACE SEMANTIC VIEW SV_REGULATORY_RISK_ANALYSIS
  TABLES (
    LOAN AS SNOW_RISK.DATA.FACT_LOAN_DETAIL PRIMARY KEY (LOAN_KEY),
    REGULATORY_RISK AS SNOW_RISK.DATA.FACT_REGULATORY_RISK PRIMARY KEY (REGULATORY_RISK_KEY),
    COUNTERPARTY AS SNOW_RISK.DATA.DIM_COUNTERPARTY PRIMARY KEY (COUNTERPARTY_KEY),
    PRODUCT AS SNOW_RISK.DATA.DIM_PRODUCT PRIMARY KEY (PRODUCT_KEY),
    DEPARTMENT AS SNOW_RISK.DATA.DIM_DEPARTMENT PRIMARY KEY (DEPARTMENT_KEY),
    RATING AS SNOW_RISK.DATA.DIM_RATING PRIMARY KEY (RATING_KEY),
    INDUSTRY AS SNOW_RISK.DATA.DIM_INDUSTRY PRIMARY KEY (INDUSTRY_KEY)
  )
  RELATIONSHIPS (
    REGULATORY_RISK (LOAN_KEY) REFERENCES LOAN,
    LOAN (COUNTERPARTY_KEY) REFERENCES COUNTERPARTY,
    LOAN (PRODUCT_KEY) REFERENCES PRODUCT,
    LOAN (DEPARTMENT_KEY) REFERENCES DEPARTMENT,
    LOAN (RATING_KEY) REFERENCES RATING,
    COUNTERPARTY (INDUSTRY_KEY) REFERENCES INDUSTRY
  )
  FACTS (
    LOAN.OUTSTANDING_AMOUNT AS OUTSTANDING_AMOUNT,
    REGULATORY_RISK.EAD AS EAD,
    REGULATORY_RISK.RISK_WEIGHT AS RISK_WEIGHT,
    REGULATORY_RISK.RWA AS RWA
  )
  DIMENSIONS (
    REGULATORY_RISK.EXPOSURE_CLASS AS EXPOSURE_CLASS,
    REGULATORY_RISK.APPROACH_TYPE AS APPROACH_TYPE,
    REGULATORY_RISK.CRM_TYPE AS CRM_TYPE,
    COUNTERPARTY.CP_NAME AS COUNTERPARTY_NAME,
    RATING.RATING_NAME AS RATING_NAME,
    INDUSTRY.INDUSTRY_NAME AS INDUSTRY_NAME,
    DEPARTMENT.DEPARTMENT_NAME AS DEPARTMENT_NAME,
    PRODUCT.PRODUCT_NAME AS PRODUCT_NAME,
    REGULATORY_RISK.BASE_DATE AS BASE_DATE
  )
  METRICS (
    REGULATORY_RISK.TOTAL_RWA AS SUM(REGULATORY_RISK.RWA),
    REGULATORY_RISK.TOTAL_EAD AS SUM(REGULATORY_RISK.EAD),
    REGULATORY_RISK.AVG_RISK_WEIGHT AS AVG(REGULATORY_RISK.RISK_WEIGHT),
    LOAN.TOTAL_OUTSTANDING AS SUM(LOAN.OUTSTANDING_AMOUNT)
  );

-- =============================================================================
-- 6. Cortex Search Service 作成
-- =============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE RISK_DOCUMENTS_CSS
  ON CONTENT
  ATTRIBUTES TITLE, DOCUMENT_TYPE, CATEGORY, KEYWORDS
  WAREHOUSE = SNOW_RISK_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'リスク管理ドキュメント検索サービス'
AS (
  SELECT
    DOCUMENT_ID,
    TITLE,
    CONTENT,
    DOCUMENT_TYPE,
    CATEGORY,
    KEYWORDS
  FROM SNOW_RISK.DATA.RISK_DOCUMENT
);

-- =============================================================================
-- 7. Cortex Agent 作成
-- =============================================================================

CREATE OR REPLACE AGENT RISK_MANAGEMENT_AGENT
  COMMENT = '信用リスク管理AIアシスタント - 内部リスク指標（EL/UL）・規制資本（RWA）の分析およびリスク管理ドキュメント検索を自然言語で実行'
  PROFILE = '{"display_name": "Risk Management Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-3-5-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    system: |
      あなたは金融機関の信用リスク管理を支援するAIアシスタントです。
      内部リスク指標（EL/UL/経済資本）、規制資本（RWA）の分析、およびリスク管理ドキュメントの検索を行います。
      専門的かつ正確な回答を心がけ、金融機関のリスク管理担当者をサポートしてください。
    orchestration: |
      【ツール選択の判断基準】
      1. InternalRiskAnalyst: EL、UL、経済資本、PD、LGD、EAD等の内部管理指標に関する質問に使用
      2. RegulatoryRiskAnalyst: RWA、リスクウェイト、エクスポージャー区分等のバーゼル規制に関する質問に使用
      3. RiskDocumentSearch: 規程、マニュアル、用語の意味、計算式、バーゼル規制の解説等に関する質問に使用
      
      【注意事項】
      - 数値データの分析にはAnalystツールを使用
      - 概念や手順の説明にはSearchツールを使用
      - 複数のツールを組み合わせて回答することも検討（例：用語説明後にデータ分析）
      - 不明確な質問の場合は、ユーザーに確認を求める
    response: |
      【応答の基本方針】
      - 日本語で丁寧かつ専門的に回答してください
      - 金融機関のリスク管理担当者が理解しやすい表現を使用
      - 専門用語は必要に応じて補足説明を加える
      
      【データ分析結果の表示】
      - 数値は千円単位または億円単位で見やすく表示
      - 表形式のデータは整形して表示
      - 重要な数値やトレンドをハイライト
      
      【ドキュメント検索結果の表示】
      - 検索結果の要点を整理して回答
      - 出典（ドキュメント名）を明記
      - 関連する追加情報があれば案内
    sample_questions:
      - question: "部門別のELを教えて"
        answer: "InternalRiskAnalystツールを使用して、部門別の期待損失（EL）を集計・分析します。"
      - question: "RWAの合計は？"
        answer: "RegulatoryRiskAnalystツールを使用して、信用リスクアセット（RWA）の合計を計算します。"
      - question: "LGDとは何ですか？"
        answer: "RiskDocumentSearchツールで用語集を検索し、LGD（デフォルト時損失率）の定義と計算方法を説明します。"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "InternalRiskAnalyst"
        description: |
          【内部リスク計測データ分析ツール】
          銀行内部で管理する信用リスク指標を分析します。

          ■ 分析可能な指標：
          - EL（Expected Loss：期待損失）：通常予想される損失額
          - UL（Unexpected Loss：非期待損失）：ストレス時に発生しうる追加損失
          - 経済資本（Economic Capital）：リスクをカバーするために必要な資本
          - PD（Probability of Default：デフォルト確率）
          - LGD（Loss Given Default：デフォルト時損失率）
          - EAD（Exposure at Default：デフォルト時エクスポージャー）

          ■ 分析軸：部門別、格付別、業種別、商品別、取引先別

          ■ 質問例：
          「部門別のELとULを集計して」「格付がBBB以下のエクスポージャーを見せて」
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "RegulatoryRiskAnalyst"
        description: |
          【規制資本データ分析ツール】
          バーゼル規制に基づく信用リスクアセット（RWA）を分析します。

          ■ 分析可能な指標：
          - RWA（Risk Weighted Assets：リスク加重資産）
          - リスクウェイト：エクスポージャー区分ごとの掛け目
          - EAD（Exposure at Default）

          ■ エクスポージャー区分：事業法人、ソブリン、金融機関、リテール、居住用不動産、株式等
          ■ 計算手法：標準的手法（SA）、内部格付手法（IRB）

          ■ 質問例：
          「エクスポージャー区分別のRWAを教えて」「部門別の平均リスクウェイトは？」
    - tool_spec:
        type: "cortex_search"
        name: "RiskDocumentSearch"
        description: |
          【リスク管理ドキュメント検索ツール】
          信用リスク管理に関する社内規程・マニュアル・解説資料を検索します。

          ■ 検索可能なドキュメント：
          - リスク管理規程・ポリシー
          - バーゼル規制の解説（バーゼルIII、IRB手法等）
          - 業務マニュアル（月次レポート作成、格付見直し等）
          - 用語集・計算式一覧
          - 参照資料（金融庁告示、業種分類等）

          ■ 質問例：
          「ELの計算式を教えて」「格付見直しのプロセスは？」「バーゼルIIIファイナライズの概要」

  tool_resources:
    InternalRiskAnalyst:
      semantic_view: "SNOW_RISK.AI.SV_INTERNAL_RISK_ANALYSIS"
    RegulatoryRiskAnalyst:
      semantic_view: "SNOW_RISK.AI.SV_REGULATORY_RISK_ANALYSIS"
    RiskDocumentSearch:
      name: "SNOW_RISK.AI.RISK_DOCUMENTS_CSS"
      max_results: 5
  $$;

-- =============================================================================
-- 8. 検証
-- =============================================================================

-- データ件数確認
SELECT 'DIM_RATING' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOW_RISK.DATA.DIM_RATING
UNION ALL
SELECT 'DIM_INDUSTRY', COUNT(*) FROM SNOW_RISK.DATA.DIM_INDUSTRY
UNION ALL
SELECT 'DIM_DEPARTMENT', COUNT(*) FROM SNOW_RISK.DATA.DIM_DEPARTMENT
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM SNOW_RISK.DATA.DIM_PRODUCT
UNION ALL
SELECT 'DIM_COUNTERPARTY', COUNT(*) FROM SNOW_RISK.DATA.DIM_COUNTERPARTY
UNION ALL
SELECT 'FACT_LOAN_DETAIL', COUNT(*) FROM SNOW_RISK.DATA.FACT_LOAN_DETAIL
UNION ALL
SELECT 'FACT_INTERNAL_RISK', COUNT(*) FROM SNOW_RISK.DATA.FACT_INTERNAL_RISK
UNION ALL
SELECT 'FACT_REGULATORY_RISK', COUNT(*) FROM SNOW_RISK.DATA.FACT_REGULATORY_RISK
UNION ALL
SELECT 'RISK_DOCUMENT', COUNT(*) FROM SNOW_RISK.DATA.RISK_DOCUMENT;

-- オブジェクト確認
SHOW TABLES IN SCHEMA SNOW_RISK.DATA;
SHOW SEMANTIC VIEWS IN SCHEMA SNOW_RISK.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOW_RISK.AI;
SHOW AGENTS IN SCHEMA SNOW_RISK.AI;

-- サンプルデータ確認
SELECT * FROM SNOW_RISK.DATA.DIM_RATING ORDER BY RATING_RANK LIMIT 5;
SELECT * FROM SNOW_RISK.DATA.DIM_DEPARTMENT WHERE DEPARTMENT_TYPE = '営業' LIMIT 5;
SELECT * FROM SNOW_RISK.DATA.FACT_LOAN_DETAIL LIMIT 5;
SELECT * FROM SNOW_RISK.DATA.FACT_INTERNAL_RISK LIMIT 5;
SELECT * FROM SNOW_RISK.DATA.FACT_REGULATORY_RISK LIMIT 5;

-- =============================================================================
-- 9. 権限付与（必要に応じてコメント解除）
-- =============================================================================

-- 他ロールへの権限付与例
-- GRANT USAGE ON DATABASE SNOW_RISK TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA SNOW_RISK.DATA TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SCHEMA SNOW_RISK.AI TO ROLE <TARGET_ROLE>;
-- GRANT SELECT ON ALL TABLES IN SCHEMA SNOW_RISK.DATA TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SEMANTIC VIEW SNOW_RISK.AI.SV_INTERNAL_RISK_ANALYSIS TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON SEMANTIC VIEW SNOW_RISK.AI.SV_REGULATORY_RISK_ANALYSIS TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON CORTEX SEARCH SERVICE SNOW_RISK.AI.RISK_DOCUMENTS_CSS TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON CORTEX AGENT SNOW_RISK.AI.RISK_MANAGEMENT_AGENT TO ROLE <TARGET_ROLE>;
-- GRANT USAGE ON WAREHOUSE SNOW_RISK_WH TO ROLE <TARGET_ROLE>;

-- =============================================================================
-- 完了メッセージ
-- =============================================================================
SELECT '✅ SNOW_RISK 環境構築完了' AS STATUS,
       'データベース: SNOW_RISK' AS DATABASE_INFO,
       'スキーマ: DATA (テーブル), AI (Semantic View, Agent)' AS SCHEMA_INFO,
       'Cortex Agent: RISK_MANAGEMENT_AGENT' AS AGENT_INFO;
