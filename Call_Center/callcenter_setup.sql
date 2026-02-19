-- =====================================================
-- SNOW_CALLCENTER 環境構築
-- コールセンター向けデモ環境
-- =====================================================

-- =============================================================================
-- 1. ロール・ウェアハウス設定
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS SNOW_CALLCENTER_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'SnowBank コールセンターデモ用ウェアハウス';

USE WAREHOUSE SNOW_CALLCENTER_WH;

-- =============================================================================
-- 2. データベース・スキーマ作成
-- =============================================================================
CREATE DATABASE IF NOT EXISTS SNOW_CALLCENTER;
CREATE SCHEMA IF NOT EXISTS SNOW_CALLCENTER.DATA;
CREATE SCHEMA IF NOT EXISTS SNOW_CALLCENTER.AI;

USE DATABASE SNOW_CALLCENTER;
USE SCHEMA DATA;

-- =============================================================================
-- 3. テーブル作成（DDL）
-- =============================================================================

-- 3.1 DIM_CUSTOMER（顧客マスタ）
CREATE OR REPLACE TABLE DIM_CUSTOMER (
    CUSTOMER_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    CUSTOMER_NUMBER VARCHAR(20) NOT NULL,
    CUSTOMER_NAME VARCHAR(100) NOT NULL,
    CUSTOMER_NAME_KANA VARCHAR(100),
    CUSTOMER_NAME_MASKED VARCHAR(20),
    BIRTH_DATE DATE,
    GENDER VARCHAR(10),
    POSTAL_CODE VARCHAR(10),
    ADDRESS VARCHAR(200),
    ADDRESS_MASKED VARCHAR(20),
    PHONE_NUMBER VARCHAR(20),
    PHONE_NUMBER_MASKED VARCHAR(20),
    EMAIL_ADDRESS VARCHAR(100),
    ACCOUNT_NUMBER VARCHAR(20),
    ACCOUNT_NUMBER_MASKED VARCHAR(20),
    CARD_NUMBER VARCHAR(20),
    CARD_NUMBER_MASKED VARCHAR(20),
    CUSTOMER_RANK VARCHAR(20) DEFAULT '一般',
    JOIN_DATE DATE NOT NULL,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE
) COMMENT='顧客マスタ：個人情報とトークン化データを含む顧客情報';

-- 3.2 DIM_PRODUCT（商品・サービスマスタ）
CREATE OR REPLACE TABLE DIM_PRODUCT (
    PRODUCT_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    PRODUCT_CODE VARCHAR(20) NOT NULL,
    PRODUCT_NAME VARCHAR(100) NOT NULL,
    PRODUCT_CATEGORY VARCHAR(50),
    DESCRIPTION VARCHAR(500),
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='商品・サービスマスタ：銀行の商品・サービス情報';

-- 3.3 DIM_OPERATOR（オペレーターマスタ）
CREATE OR REPLACE TABLE DIM_OPERATOR (
    OPERATOR_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    OPERATOR_ID VARCHAR(20) NOT NULL,
    OPERATOR_NAME VARCHAR(100) NOT NULL,
    TEAM_NAME VARCHAR(50),
    SKILL_LEVEL VARCHAR(20),
    HIRE_DATE DATE,
    ACTIVE_FLAG BOOLEAN DEFAULT TRUE,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='オペレーターマスタ：コールセンター担当者情報';

-- 3.4 DIM_INQUIRY_CATEGORY（問い合わせカテゴリマスタ）
CREATE OR REPLACE TABLE DIM_INQUIRY_CATEGORY (
    CATEGORY_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    CATEGORY_CODE VARCHAR(20) NOT NULL,
    CATEGORY_NAME VARCHAR(100) NOT NULL,
    PARENT_CATEGORY VARCHAR(50),
    PRIORITY_LEVEL VARCHAR(20) DEFAULT '通常',
    ESCALATION_REQUIRED BOOLEAN DEFAULT FALSE,
    RPA_ELIGIBLE BOOLEAN DEFAULT FALSE,
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='問い合わせカテゴリマスタ：問い合わせ種別と処理ルール';

-- 3.5 FACT_INQUIRY（問い合わせファクト）
CREATE OR REPLACE TABLE FACT_INQUIRY (
    INQUIRY_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    INQUIRY_NUMBER VARCHAR(20) NOT NULL,
    CUSTOMER_KEY NUMBER(38,0),
    OPERATOR_KEY NUMBER(38,0),
    CATEGORY_KEY NUMBER(38,0),
    PRODUCT_KEY NUMBER(38,0),
    INQUIRY_DATETIME TIMESTAMP_NTZ NOT NULL,
    CHANNEL VARCHAR(20) DEFAULT '電話',
    INQUIRY_SUMMARY VARCHAR(500),
    RESPONSE_SUMMARY VARCHAR(1000),
    HANDLE_TIME_SECONDS NUMBER(10,0),
    HOLD_TIME_SECONDS NUMBER(10,0),
    SATISFACTION_SCORE NUMBER(1,0),
    STATUS VARCHAR(20) DEFAULT '完了',
    ESCALATED_FLAG BOOLEAN DEFAULT FALSE,
    RPA_PROCESSED_FLAG BOOLEAN DEFAULT FALSE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='問い合わせファクト：顧客からの問い合わせ記録';

-- 3.6 FACT_CALL_TRANSCRIPT（通話テキストファクト）
CREATE OR REPLACE TABLE FACT_CALL_TRANSCRIPT (
    TRANSCRIPT_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    TRANSCRIPT_ID VARCHAR(20) NOT NULL,
    INQUIRY_KEY NUMBER(38,0),
    CUSTOMER_KEY NUMBER(38,0),
    OPERATOR_KEY NUMBER(38,0),
    CALL_START_DATETIME TIMESTAMP_NTZ NOT NULL,
    CALL_END_DATETIME TIMESTAMP_NTZ,
    CALL_DURATION_SECONDS NUMBER(10,0),
    RAW_TRANSCRIPT VARCHAR(16777216),
    TRANSCRIPT_MASKED VARCHAR(16777216),
    AI_SUMMARY VARCHAR(2000),
    SENTIMENT_SCORE NUMBER(3,2),
    KEYWORDS VARCHAR(500),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT='通話テキストファクト：AmiVoice連携想定の通話テキストデータ';

-- 3.7 FACT_RPA_INSTRUCTION（RPA処理指示ファクト）
CREATE OR REPLACE TABLE FACT_RPA_INSTRUCTION (
    INSTRUCTION_KEY NUMBER(38,0) NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER,
    INSTRUCTION_ID VARCHAR(20) NOT NULL,
    INQUIRY_KEY NUMBER(38,0),
    CUSTOMER_KEY NUMBER(38,0),
    PROCESS_TYPE VARCHAR(50) NOT NULL,
    PROCESS_PARAMS VARIANT,
    PRIORITY VARCHAR(20) DEFAULT '通常',
    STATUS VARCHAR(20) DEFAULT '処理待ち',
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PROCESSED_AT TIMESTAMP_NTZ,
    RESULT_MESSAGE VARCHAR(500)
) COMMENT='RPA処理指示ファクト：自動処理連携用の指示データ（PROCESS_PARAMSはVARIANT型）';

-- 3.8 CALL_CENTER_DOCUMENT（コールセンタードキュメント）
CREATE OR REPLACE TABLE CALL_CENTER_DOCUMENT (
    DOCUMENT_ID VARCHAR(20) NOT NULL,
    TITLE VARCHAR(200) NOT NULL,
    CONTENT VARCHAR(16777216) NOT NULL,
    DOCUMENT_TYPE VARCHAR(50),
    CATEGORY VARCHAR(50),
    KEYWORDS VARCHAR(500),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    VERSION NUMBER(10,0) DEFAULT 1
) COMMENT='コールセンタードキュメント：FAQ、マニュアル、スクリプト';

ALTER TABLE CALL_CENTER_DOCUMENT SET CHANGE_TRACKING = TRUE;

-- =============================================================================
-- 4. サンプルデータ投入
-- =============================================================================

-- 4.1 DIM_PRODUCT（20件）
INSERT INTO DIM_PRODUCT (PRODUCT_CODE, PRODUCT_NAME, PRODUCT_CATEGORY, DESCRIPTION)
VALUES
('PRD001', '普通預金', '預金', '日常の入出金に便利な預金口座'),
('PRD002', '定期預金', '預金', '一定期間お預けいただく預金。金利優遇あり'),
('PRD003', '外貨預金', '預金', '外貨建ての預金口座。米ドル、ユーロ等に対応'),
('PRD004', '住宅ローン', 'ローン', 'マイホーム購入・建築資金のローン'),
('PRD005', 'マイカーローン', 'ローン', '自動車購入資金のローン'),
('PRD006', 'カードローン', 'ローン', 'いつでも借入・返済可能なローン'),
('PRD007', '教育ローン', 'ローン', '教育資金のためのローン'),
('PRD008', 'フリーローン', 'ローン', '資金使途自由なローン'),
('PRD009', 'クレジットカード（一般）', 'カード', '年会費無料の一般カード'),
('PRD010', 'クレジットカード（ゴールド）', 'カード', '充実の特典付きゴールドカード'),
('PRD011', 'デビットカード', 'カード', '口座直結の即時決済カード'),
('PRD012', 'ETCカード', 'カード', '高速道路料金支払い用カード'),
('PRD013', '投資信託', '投資', '専門家が運用する投資商品'),
('PRD014', 'NISA口座', '投資', '非課税で投資できる口座'),
('PRD015', 'iDeCo', '投資', '個人型確定拠出年金'),
('PRD016', '火災保険', '保険', '住宅・家財を守る保険'),
('PRD017', '生命保険', '保険', '万一の際の保障'),
('PRD018', '海外送金', 'サービス', '海外への送金サービス'),
('PRD019', 'インターネットバンキング', 'サービス', 'オンラインで取引可能なサービス'),
('PRD020', '貸金庫', 'サービス', '大切な品物を保管するサービス');

-- 4.2 DIM_OPERATOR（30件）
INSERT INTO DIM_OPERATOR (OPERATOR_ID, OPERATOR_NAME, TEAM_NAME, SKILL_LEVEL, HIRE_DATE)
SELECT
    'OP' || LPAD(SEQ4()::VARCHAR, 3, '0'),
    ARRAY_CONSTRUCT('佐藤', '鈴木', '高橋', '田中', '渡辺', '伊藤', '山本', '中村', '小林', '加藤',
                    '吉田', '山田', '佐々木', '山口', '松本', '井上', '木村', '林', '斎藤', '清水',
                    '山崎', '森', '池田', '橋本', '阿部', '石川', '前田', '藤田', '小川', '後藤')[SEQ4()::INT] || ' ' ||
    CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 
         THEN ARRAY_CONSTRUCT('太郎', '一郎', '健太', '大輔', '翔太')[UNIFORM(0, 4, RANDOM())::INT]
         ELSE ARRAY_CONSTRUCT('花子', '美咲', '陽子', '恵子', '由美')[UNIFORM(0, 4, RANDOM())::INT]
    END,
    ARRAY_CONSTRUCT('預金チーム', 'ローンチーム', 'カードチーム', '総合窓口', 'エスカレーション対応')[UNIFORM(0, 4, RANDOM())::INT],
    ARRAY_CONSTRUCT('ジュニア', 'ミドル', 'シニア', 'エキスパート')[UNIFORM(0, 3, RANDOM())::INT],
    DATEADD(DAY, -UNIFORM(100, 3000, RANDOM()), CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- 4.3 DIM_INQUIRY_CATEGORY（25件）
INSERT INTO DIM_INQUIRY_CATEGORY (CATEGORY_CODE, CATEGORY_NAME, PARENT_CATEGORY, PRIORITY_LEVEL, ESCALATION_REQUIRED, RPA_ELIGIBLE)
VALUES
('CAT001', '残高照会', '口座関連', '通常', FALSE, FALSE),
('CAT002', '入出金明細', '口座関連', '通常', FALSE, FALSE),
('CAT003', '口座開設', '口座関連', '通常', FALSE, TRUE),
('CAT004', '口座解約', '口座関連', '高', TRUE, TRUE),
('CAT005', '名義変更', '口座関連', '通常', FALSE, TRUE),
('CAT006', 'カード紛失', 'カード関連', '緊急', TRUE, TRUE),
('CAT007', 'カード破損', 'カード関連', '高', FALSE, TRUE),
('CAT008', '暗証番号', 'カード関連', '高', FALSE, TRUE),
('CAT009', '利用限度額', 'カード関連', '通常', FALSE, TRUE),
('CAT010', '不正利用', 'カード関連', '緊急', TRUE, TRUE),
('CAT011', '振込方法', '振込・送金', '通常', FALSE, FALSE),
('CAT012', '振込手数料', '振込・送金', '通常', FALSE, FALSE),
('CAT013', '振込エラー', '振込・送金', '高', FALSE, FALSE),
('CAT014', '組戻し', '振込・送金', '高', TRUE, TRUE),
('CAT015', '返済相談', 'ローン関連', '高', TRUE, FALSE),
('CAT016', '繰上返済', 'ローン関連', '通常', FALSE, TRUE),
('CAT017', '金利照会', 'ローン関連', '通常', FALSE, FALSE),
('CAT018', '延滞相談', 'ローン関連', '緊急', TRUE, FALSE),
('CAT019', '住所変更', 'その他', '通常', FALSE, TRUE),
('CAT020', '届出印変更', 'その他', '通常', FALSE, TRUE),
('CAT021', '相続手続き', 'その他', '高', TRUE, FALSE),
('CAT022', 'システム障害', 'その他', '緊急', TRUE, FALSE),
('CAT023', '苦情・クレーム', 'その他', '緊急', TRUE, FALSE),
('CAT024', '商品問い合わせ', 'その他', '通常', FALSE, FALSE),
('CAT025', 'その他一般', 'その他', '通常', FALSE, FALSE);

-- 4.4 DIM_CUSTOMER（200件）
INSERT INTO DIM_CUSTOMER (CUSTOMER_NUMBER, CUSTOMER_NAME, CUSTOMER_NAME_KANA, CUSTOMER_NAME_MASKED, BIRTH_DATE, GENDER, POSTAL_CODE, ADDRESS, ADDRESS_MASKED, PHONE_NUMBER, PHONE_NUMBER_MASKED, EMAIL_ADDRESS, ACCOUNT_NUMBER, ACCOUNT_NUMBER_MASKED, CARD_NUMBER, CARD_NUMBER_MASKED, CUSTOMER_RANK, JOIN_DATE, ACTIVE_FLAG)
SELECT 
    'C' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    last_name || ' ' || first_name,
    'カナシメイ',
    '[NAME_' || SEQ4()::VARCHAR || ']',
    DATEADD(DAY, -UNIFORM(9000, 25000, RANDOM()), CURRENT_DATE()),
    CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 THEN '男性' ELSE '女性' END,
    UNIFORM(100, 999, RANDOM())::VARCHAR || '-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR,
    ARRAY_CONSTRUCT('東京都', '神奈川県', '千葉県', '埼玉県', '大阪府', '愛知県', '福岡県', '北海道', '宮城県', '広島県')[UNIFORM(0, 9, RANDOM())::INT] || pref_city,
    '[ADDR_' || SEQ4()::VARCHAR || ']',
    '0' || UNIFORM(3, 9, RANDOM())::VARCHAR || '0-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR || '-' || UNIFORM(1000, 9999, RANDOM())::VARCHAR,
    '[PHONE_' || SEQ4()::VARCHAR || ']',
    'user' || SEQ4()::VARCHAR || '@example.com',
    UNIFORM(1000000, 9999999, RANDOM())::VARCHAR,
    '[ACCT_XXXX' || RIGHT(UNIFORM(1000000, 9999999, RANDOM())::VARCHAR, 4) || ']',
    '4' || UNIFORM(100000000000000, 999999999999999, RANDOM())::VARCHAR,
    '[CARD_XXXX' || RIGHT(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4) || ']',
    ARRAY_CONSTRUCT('一般', '一般', '一般', '一般', '一般', 'シルバー', 'シルバー', 'ゴールド', 'ゴールド', 'プラチナ')[UNIFORM(0, 9, RANDOM())::INT],
    DATEADD(DAY, -UNIFORM(100, 3650, RANDOM()), CURRENT_DATE()),
    TRUE
FROM (
    SELECT 
        SEQ4(),
        ARRAY_CONSTRUCT('佐藤', '鈴木', '高橋', '田中', '渡辺', '伊藤', '山本', '中村', '小林', '加藤',
                        '吉田', '山田', '佐々木', '山口', '松本', '井上', '木村', '林', '斎藤', '清水')[UNIFORM(0, 19, RANDOM())::INT] AS last_name,
        CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 
             THEN ARRAY_CONSTRUCT('太郎', '一郎', '健太', '大輔', '翔太', '拓也', '直樹', '哲也', '雄一', '浩二')[UNIFORM(0, 9, RANDOM())::INT]
             ELSE ARRAY_CONSTRUCT('花子', '美咲', '陽子', '恵子', '由美', '裕子', '真理', '久美子', '明美', '幸子')[UNIFORM(0, 9, RANDOM())::INT]
        END AS first_name,
        ARRAY_CONSTRUCT('新宿区', '渋谷区', '港区', '品川区', '目黒区', '世田谷区', '中央区', '千代田区', '豊島区', '文京区')[UNIFORM(0, 9, RANDOM())::INT] AS pref_city
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
);

-- 4.5 FACT_INQUIRY（2000件）
INSERT INTO FACT_INQUIRY (INQUIRY_NUMBER, CUSTOMER_KEY, OPERATOR_KEY, CATEGORY_KEY, PRODUCT_KEY, INQUIRY_DATETIME, CHANNEL, INQUIRY_SUMMARY, RESPONSE_SUMMARY, HANDLE_TIME_SECONDS, HOLD_TIME_SECONDS, SATISFACTION_SCORE, STATUS, ESCALATED_FLAG, RPA_PROCESSED_FLAG)
SELECT 
    'INQ' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    UNIFORM(1, 200, RANDOM()),
    UNIFORM(1, 30, RANDOM()),
    cat_key,
    CASE WHEN UNIFORM(0, 4, RANDOM()) < 4 THEN UNIFORM(1, 20, RANDOM()) ELSE NULL END,
    DATEADD(MINUTE, UNIFORM(0, 525600, RANDOM()), '2024-01-01 08:00:00'::TIMESTAMP),
    ARRAY_CONSTRUCT('電話', '電話', '電話', '電話', 'メール', 'チャット', 'Web')[UNIFORM(0, 6, RANDOM())::INT],
    ARRAY_CONSTRUCT(
        '口座残高の確認をしたい',
        'カードが使えなくなった',
        '振込の方法を教えてほしい',
        '住所変更の手続きをしたい',
        'ローンの返済について相談したい',
        'カードを紛失した',
        '不正利用があったかもしれない',
        '暗証番号を忘れた',
        '限度額を変更したい',
        'カードが破損した'
    )[UNIFORM(0, 9, RANDOM())::INT],
    '対応完了しました',
    UNIFORM(120, 1800, RANDOM()),
    UNIFORM(0, 300, RANDOM()),
    UNIFORM(1, 5, RANDOM()),
    ARRAY_CONSTRUCT('完了', '完了', '完了', '完了', '完了', '対応中', 'エスカレーション中')[UNIFORM(0, 6, RANDOM())::INT],
    UNIFORM(0, 9, RANDOM()) < 1,
    UNIFORM(0, 9, RANDOM()) < 3
FROM (
    SELECT 
        SEQ4(),
        UNIFORM(1, 25, RANDOM()) AS cat_key
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
);

-- 4.6 FACT_CALL_TRANSCRIPT（500件）
INSERT INTO FACT_CALL_TRANSCRIPT (TRANSCRIPT_ID, INQUIRY_KEY, CUSTOMER_KEY, OPERATOR_KEY, CALL_START_DATETIME, CALL_END_DATETIME, CALL_DURATION_SECONDS, RAW_TRANSCRIPT, TRANSCRIPT_MASKED, AI_SUMMARY, SENTIMENT_SCORE, KEYWORDS)
SELECT
    'TR' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    SEQ4() + 1,
    UNIFORM(1, 200, RANDOM()),
    UNIFORM(1, 30, RANDOM()),
    call_start,
    DATEADD(SECOND, call_duration, call_start),
    call_duration,
    transcript_template,
    REGEXP_REPLACE(REGEXP_REPLACE(transcript_template, '[0-9]{7}', '[ACCT_XXXX]'), '[0-9]{16}', '[CARD_XXXX]'),
    ARRAY_CONSTRUCT(
        'カード破損による再発行依頼。本人確認完了、再発行手続き実施。',
        '残高照会の問い合わせ。口座情報を案内し対応完了。',
        '振込方法の確認。インターネットバンキングでの手順を説明。',
        '住所変更の依頼。変更手続き完了、新住所へ郵送物送付予定。',
        'カード紛失の緊急連絡。利用停止処理実施、再発行手配。',
        'ローン返済の相談。返済シミュレーションを提示し検討中。',
        '暗証番号再設定の依頼。本人確認後、再設定手順を案内。',
        '不正利用の疑いの相談。取引履歴を確認し、該当なし。',
        '限度額変更の依頼。審査申請を受付、結果は後日連絡。',
        'クレジットカード利用明細の確認。明細詳細を説明。'
    )[UNIFORM(0, 9, RANDOM())::INT],
    ROUND(UNIFORM(0.3, 0.9, RANDOM()), 2),
    ARRAY_CONSTRUCT(
        'カード,再発行,破損',
        '残高,照会,口座',
        '振込,方法,手数料',
        '住所,変更,届出',
        'カード,紛失,停止',
        'ローン,返済,相談',
        '暗証番号,再設定,確認',
        '不正,利用,調査',
        '限度額,変更,審査',
        '明細,確認,利用'
    )[UNIFORM(0, 9, RANDOM())::INT]
FROM (
    SELECT 
        SEQ4(),
        DATEADD(MINUTE, UNIFORM(0, 525600, RANDOM()), '2024-01-01 08:00:00'::TIMESTAMP) AS call_start,
        UNIFORM(180, 1200, RANDOM()) AS call_duration,
        'オペレーター: お電話ありがとうございます。SnowBankコールセンターでございます。\n' ||
        '顧客: ' || ARRAY_CONSTRUCT(
            'クレジットカードが破損してしまいました。',
            '口座残高を確認したいのですが。',
            '振込の方法を教えてください。',
            '住所が変わったので届け出たいです。',
            'カードをなくしてしまいました。',
            'ローンの返済について相談したいです。',
            '暗証番号を忘れてしまいました。',
            '身に覚えのない利用があるようです。',
            'カードの限度額を上げたいです。',
            '先月の利用明細を確認したいです。'
        )[UNIFORM(0, 9, RANDOM())::INT] || '\n' ||
        'オペレーター: かしこまりました。ご本人確認をさせていただきます。お名前とカード番号をお願いいたします。\n' ||
        '顧客: はい、山田太郎です。カード番号は4123456789012345です。\n' ||
        'オペレーター: ありがとうございます。確認が取れました。' AS transcript_template
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
);

-- 4.7 FACT_RPA_INSTRUCTION（300件）
INSERT INTO FACT_RPA_INSTRUCTION (INSTRUCTION_ID, INQUIRY_KEY, CUSTOMER_KEY, PROCESS_TYPE, PROCESS_PARAMS, PRIORITY, STATUS, PROCESSED_AT, RESULT_MESSAGE)
SELECT
    'RPA' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    SEQ4() + 1,
    cust_key,
    process_type,
    OBJECT_CONSTRUCT(
        'customer_key', '[CUST_' || cust_key::VARCHAR || ']',
        'process_type', process_type,
        'process_detail', process_detail,
        'card_number', CASE WHEN process_type IN ('カード再発行', '利用停止') THEN '[CARD_XXXX' || UNIFORM(1000, 9999, RANDOM())::VARCHAR || ']' ELSE NULL END,
        'delivery_address', CASE WHEN process_type IN ('カード再発行', '住所変更') THEN '登録住所' ELSE NULL END,
        'request_datetime', CURRENT_TIMESTAMP()::VARCHAR,
        'notes', additional_note
    ),
    ARRAY_CONSTRUCT('通常', '通常', '通常', '高', '緊急')[UNIFORM(0, 4, RANDOM())::INT],
    ARRAY_CONSTRUCT('処理待ち', '処理中', '完了', '完了', '完了')[UNIFORM(0, 4, RANDOM())::INT],
    CASE WHEN UNIFORM(0, 4, RANDOM()) >= 2 THEN DATEADD(MINUTE, UNIFORM(10, 120, RANDOM()), CURRENT_TIMESTAMP()) ELSE NULL END,
    CASE WHEN UNIFORM(0, 4, RANDOM()) >= 2 THEN '処理完了' ELSE NULL END
FROM (
    SELECT 
        SEQ4(),
        UNIFORM(1, 200, RANDOM()) AS cust_key,
        ARRAY_CONSTRUCT('カード再発行', '住所変更', '暗証番号再設定', '口座開設', '利用停止', '限度額変更')[UNIFORM(0, 5, RANDOM())::INT] AS process_type,
        ARRAY_CONSTRUCT('破損による再発行', '転居に伴う変更', '暗証番号忘れ', '新規開設希望', '紛失による停止', '限度額増額希望')[UNIFORM(0, 5, RANDOM())::INT] AS process_detail,
        ARRAY_CONSTRUCT('通常対応', '至急対応希望', '電話での本人確認済み', 'eKYC確認済み', '窓口確認済み', NULL)[UNIFORM(0, 5, RANDOM())::INT] AS additional_note
    FROM TABLE(GENERATOR(ROWCOUNT => 300))
);

-- 4.8 CALL_CENTER_DOCUMENT（32件）
INSERT INTO CALL_CENTER_DOCUMENT (DOCUMENT_ID, TITLE, CONTENT, DOCUMENT_TYPE, CATEGORY, KEYWORDS)
VALUES
-- FAQ（10件）
('DOC001', '口座残高の確認方法', '口座残高は以下の方法で確認できます。\n\n1. インターネットバンキング\n   - ログイン後「口座情報」メニューから確認\n   - 24時間いつでも確認可能\n\n2. ATM\n   - キャッシュカードを挿入し「残高照会」を選択\n   - 全国のコンビニATMでも利用可能\n\n3. 電話\n   - 自動音声サービス（0120-XXX-XXX）で確認\n   - 暗証番号が必要\n\n4. 通帳記帳\n   - ATMで通帳を記帳すると最新残高を確認可能', 'FAQ', '口座', '残高,確認,照会,インターネットバンキング,ATM'),
('DOC002', '振込手数料について', '振込手数料は以下の通りです。\n\n【当行宛て】\n- インターネットバンキング: 無料\n- ATM: 110円\n- 窓口: 330円\n\n【他行宛て】\n- インターネットバンキング: 220円\n- ATM: 330円\n- 窓口: 550円\n\n※3万円以上の場合は上記に110円加算\n※ゴールド会員以上は当行宛て無料、他行宛て月3回まで無料', 'FAQ', '振込', '振込,手数料,料金,送金'),
('DOC003', 'キャッシュカード紛失時の対応', 'キャッシュカードを紛失された場合は、以下の手順で対応してください。\n\n【緊急連絡先】\n- 24時間対応: 0120-XXX-XXX\n- 海外から: +81-3-XXXX-XXXX\n\n【手順】\n1. 上記番号に電話し、カード利用停止を依頼\n2. 警察に届出（届出番号を控える）\n3. 再発行手続き\n   - 届出番号、本人確認書類を持参の上、窓口で手続き\n   - 再発行手数料: 1,100円\n   - 届くまでの期間: 約1週間\n\n【注意】\n- 見つかった場合も再発行をお勧めします\n- 不正利用があった場合は全額補償（届出後60日以内の被害）', 'FAQ', 'カード', 'カード,紛失,停止,再発行,盗難'),
('DOC004', '住所変更の手続き', '住所変更のお手続き方法は以下の通りです。\n\n【インターネットバンキング】\n1. ログイン後「各種届出」を選択\n2. 「住所変更」を選択\n3. 新住所を入力して完了\n※即時反映\n\n【窓口】\n必要書類:\n- 届出印\n- 本人確認書類（運転免許証等）\n- 新住所確認書類（住民票等）\n\n【郵送】\n- 「住所変更届」用紙を取り寄せ\n- 必要事項を記入し、本人確認書類のコピーを同封\n\n【注意】\n- カード、通帳、届出印の再発行が必要な場合は窓口のみ\n- マイナンバー届出済みの場合、マイナンバー変更届も必要', 'FAQ', '届出', '住所,変更,届出,引越し'),
('DOC005', '暗証番号の再設定', '暗証番号をお忘れの場合、以下の方法で再設定できます。\n\n【ATMでの再設定】\n- キャッシュカードと届出印をお持ちください\n- 「各種届出」→「暗証番号変更」を選択\n- 現在の暗証番号が必要です\n\n【窓口での再設定】\n現在の暗証番号が不明な場合:\n- 届出印\n- 本人確認書類\n- キャッシュカード\nを持参の上、窓口で手続き\n\n【暗証番号のルール】\n- 4桁の数字\n- 生年月日、電話番号、連番は避けてください\n- 3回連続で間違えるとロックされます', 'FAQ', 'カード', '暗証番号,再設定,ロック,変更'),
('DOC006', 'インターネットバンキングのログイン方法', 'インターネットバンキングへのログイン方法です。\n\n【初回ログイン】\n1. 公式サイトから「インターネットバンキング」を選択\n2. 「初回登録」をクリック\n3. 契約番号（郵送でお届け）とキャッシュカード暗証番号を入力\n4. ログインパスワード、取引パスワードを設定\n\n【通常ログイン】\n1. 契約番号を入力\n2. ログインパスワードを入力\n\n【ログインできない場合】\n- パスワード忘れ: 再発行手続きが必要（窓口または郵送）\n- ロック: 5回連続失敗でロック。解除は窓口で手続き', 'FAQ', 'サービス', 'インターネットバンキング,ログイン,オンライン'),
('DOC007', '外貨預金の為替レート確認', '外貨預金の為替レートは以下の方法で確認できます。\n\n【確認方法】\n1. 公式サイト: 「為替レート」ページで最新レートを表示\n2. インターネットバンキング: 外貨預金メニュー内に表示\n3. 窓口: 電光掲示板で表示\n\n【レート更新タイミング】\n- 営業日の午前10時頃に更新\n- 相場急変時は随時更新\n\n【手数料】\n米ドル: 片道1円（往復2円）\nユーロ: 片道1.5円（往復3円）\nその他: 通貨により異なる\n\n※インターネットバンキングなら手数料優遇あり', 'FAQ', '預金', '外貨,為替,レート,ドル,ユーロ'),
('DOC008', 'ローン返済日の変更', 'ローンの返済日変更についてご案内します。\n\n【変更可能な返済日】\n毎月: 5日、10日、15日、20日、25日、末日\n\n【変更方法】\n窓口でのお手続きとなります。\n\n必要書類:\n- 届出印\n- 本人確認書類\n- ローン契約書（お持ちの場合）\n\n【注意事項】\n- 変更は翌月または翌々月から適用\n- 遅延がある場合は変更不可\n- 年に1回まで変更可能\n- ボーナス返済月の変更も同時に可能', 'FAQ', 'ローン', 'ローン,返済,変更,日付'),
('DOC009', 'クレジットカード利用明細の確認', 'クレジットカードの利用明細は以下の方法で確認できます。\n\n【Web明細】\n- カード会員サイトにログイン\n- 「利用明細」メニューから確認\n- 過去24ヶ月分を閲覧可能\n- PDF形式でダウンロード可能\n\n【紙の明細】\n- 毎月15日頃に郵送（締め日: 前月末）\n- Web明細に切り替えると年間600円割引\n\n【速報明細】\n- カード会員サイトで確定前の利用を確認可能\n- 反映まで1〜3日かかる場合あり\n\n【明細の見方】\n- 利用日: 実際に利用した日付\n- 利用店名: 加盟店名\n- 支払区分: 1回、分割、リボ等', 'FAQ', 'カード', 'クレジットカード,明細,利用,確認'),
('DOC010', '相続手続きの流れ', '口座名義人がお亡くなりになった場合の相続手続きについてご案内します。\n\n【必要な届出】\n1. 死亡届（口座凍結）\n2. 相続届（払戻し・名義変更）\n\n【必要書類】\n- 戸籍謄本（被相続人の出生から死亡まで）\n- 相続人全員の戸籍謄本\n- 遺産分割協議書または遺言書\n- 相続人全員の印鑑証明書\n- 届出人の本人確認書類\n\n【手続きの流れ】\n1. 電話で死亡届（口座凍結）\n2. 窓口で必要書類の案内を受ける\n3. 書類を準備して窓口で届出\n4. 審査（1〜2週間）\n5. 払戻しまたは名義変更\n\n【注意】\n- 凍結後は入出金不可\n- 公共料金等の引落しも停止', 'FAQ', '相続', '相続,死亡,届出,手続き,名義変更'),

-- マニュアル（12件）
('DOC011', '新規口座開設対応手順', '新規口座開設の対応手順マニュアルです。\n\n【受付時の確認事項】\n1. 開設目的の確認（給与受取、貯蓄、事業用等）\n2. 本人確認書類の種類\n3. 届出印の有無\n4. マイナンバーの届出\n\n【本人確認書類】\n顔写真付き1点: 運転免許証、マイナンバーカード、パスポート\n顔写真なし2点: 健康保険証+住民票等\n\n【システム入力手順】\n1. 業務端末で「口座開設」を選択\n2. 本人確認書類をスキャン\n3. 顧客情報を入力\n4. 口座種別を選択\n5. 承認者確認を依頼\n\n【完了後の案内】\n- キャッシュカードは1週間程度で郵送\n- 届出印を大切に保管\n- インターネットバンキングの案内', 'マニュアル', '口座', '口座開設,新規,手順,本人確認'),
('DOC012', 'クレーム対応マニュアル', 'クレーム対応の基本マニュアルです。\n\n【初期対応の心構え】\n- まず傾聴し、お客様の話を遮らない\n- 共感の言葉を述べる（「ご不便をおかけして申し訳ございません」）\n- メモを取りながら聞く\n\n【対応の流れ】\n1. 傾聴（5分程度）\n2. 事実確認（システム照会）\n3. お詫びと説明\n4. 解決策の提示\n5. クロージング\n\n【NGワード】\n- 「できません」→「〇〇でしたら可能です」\n- 「決まりですので」→「〇〇という理由がございまして」\n- 「担当ではありません」→「確認してまいります」\n\n【エスカレーション基準】\n- 30分以上かかる場合\n- お客様が役職者を要求された場合\n- 金銭的補償を求められた場合\n- 録音・録画されている場合', 'マニュアル', 'クレーム', 'クレーム,苦情,対応,エスカレーション'),
('DOC013', 'エスカレーション判断基準', 'エスカレーションの判断基準と手順です。\n\n【即時エスカレーション必須】\n- 不正利用・詐欺被害の可能性\n- 法的措置の示唆があった場合\n- マスコミ・SNS投稿の示唆\n- お客様の体調異変\n- 暴言・脅迫があった場合\n\n【15分経過でエスカレーション検討】\n- 解決策が見つからない\n- お客様が納得されない\n- 複雑な商品・サービスの問い合わせ\n\n【エスカレーション手順】\n1. お客様に「確認してまいります」と伝え保留\n2. SVに状況を簡潔に報告\n3. SVの指示に従う\n4. 転送の場合は「詳しい者に代わります」と案内\n\n【報告事項】\n- お客様名\n- 問い合わせ内容\n- 対応経緯\n- 問題点', 'マニュアル', 'エスカレーション', 'エスカレーション,判断,基準,転送'),
('DOC014', '本人確認手順（eKYC対応含む）', '本人確認の手順とeKYC対応についてご案内します。\n\n【電話での本人確認】\n確認項目（3点以上一致で確認完了）:\n1. 氏名\n2. 生年月日\n3. 登録電話番号\n4. 登録住所\n5. 口座番号\n\n【eKYC（オンライン本人確認）】\n対象手続き: 口座開設、住所変更、限度額変更\n\n手順:\n1. アプリで本人確認書類を撮影\n2. 顔写真を撮影（まばたき検知あり）\n3. 書類と顔の照合\n4. 審査（通常数分〜24時間）\n\n【確認できない場合】\n- 窓口での手続きを案内\n- 必要書類: 本人確認書類2点+届出印', 'マニュアル', '本人確認', '本人確認,eKYC,確認,セキュリティ'),
('DOC015', '高齢者対応ガイドライン', '高齢のお客様への対応ガイドラインです。\n\n【基本姿勢】\n- ゆっくり、はっきり話す\n- 専門用語を避け、平易な言葉を使う\n- 必要に応じて繰り返し説明\n- 急がせない\n\n【注意すべきサイン】\n- 同じ質問を繰り返す\n- 話の辻褄が合わない\n- 家族に内緒にしたいと言う\n- 急いで手続きしたいと焦っている\n\n【詐欺被害防止】\n以下の場合は確認を徹底:\n- 高額の振込（特に初めての相手）\n- 電話で指示されている様子\n- 「誰にも言わないで」という発言\n\n確認方法:\n- 振込目的の確認\n- 家族への連絡の提案\n- 警察相談窓口の案内', 'マニュアル', '高齢者', '高齢者,シニア,対応,詐欺防止'),
('DOC016', '詐欺被害対応フロー', '詐欺被害が疑われる場合の対応フローです。\n\n【振り込め詐欺の兆候】\n- 「今すぐ振り込んで」と急かされている\n- 相手の連絡先を知らない\n- 家族の事故・事件を装う電話\n- 還付金があると言われた\n\n【対応手順】\n1. 落ち着いて状況を確認\n   「差し支えなければ、お振込みの経緯を教えていただけますか」\n\n2. 疑わしい場合\n   - 「念のため、ご家族に確認されてはいかがでしょうか」\n   - 「警察に相談されることをお勧めします」\n\n3. 振込を止める場合\n   - SVに報告\n   - 組戻し手続きの案内\n\n【相談窓口】\n- 警察相談: #9110\n- 消費者ホットライン: 188', 'マニュアル', '詐欺', '詐欺,振り込め詐欺,被害,防止'),
('DOC017', 'システム障害時の対応手順', 'システム障害発生時の対応手順です。\n\n【障害レベル】\nレベル1: 一部機能の遅延\nレベル2: 一部機能の停止\nレベル3: 全面停止\n\n【初動対応】\n1. 障害情報ポータルを確認\n2. SVに報告・確認\n3. お客様への案内\n\n【案内例文】\n「現在、システムの一部に障害が発生しております。ご不便をおかけして申し訳ございません。復旧次第、改めてご連絡させていただきます。」\n\n【禁止事項】\n- 復旧時間の約束\n- 原因の推測を伝える\n- SNS等への投稿\n\n【復旧後】\n- 未完了の手続きの確認\n- お客様へのフォロー連絡', 'マニュアル', 'システム', 'システム障害,対応,復旧,トラブル'),
('DOC018', '個人情報取扱いルール', '個人情報の取扱いに関するルールです。\n\n【基本原則】\n- 業務上必要な範囲でのみ閲覧\n- 閲覧履歴は記録される\n- 口頭での情報提供も記録\n\n【禁止事項】\n- 業務外での顧客情報閲覧\n- 画面の撮影・メモの持ち出し\n- 第三者への情報提供（本人同意なし）\n- SNS等への投稿\n\n【電話での情報提供範囲】\n本人確認後に提供可能:\n- 口座残高\n- 直近の取引\n- 届出住所・電話番号\n\n本人確認後も提供不可:\n- 他口座の情報\n- ローン審査結果の詳細\n- 家族の情報（本人以外）\n\n【事故発生時】\n- 即時SVに報告\n- 証拠保全（画面キャプチャ等）\n- 報告書作成', 'マニュアル', 'セキュリティ', '個人情報,セキュリティ,取扱い,プライバシー'),
('DOC019', '通話品質評価基準', '通話品質の評価基準です。\n\n【評価項目】\n1. オープニング（10点）\n   - 名乗り、挨拶の適切さ\n   - 声のトーン、明るさ\n\n2. ヒアリング（20点）\n   - 傾聴の姿勢\n   - 適切な相槌\n   - 質問の仕方\n\n3. 説明・案内（30点）\n   - 正確性\n   - 分かりやすさ\n   - 専門用語の回避\n\n4. クロージング（10点）\n   - 確認の有無\n   - 感謝の言葉\n\n5. 全体印象（30点）\n   - 対応時間の適切さ\n   - 顧客満足度\n   - 問題解決度\n\n【評価結果の活用】\n- 月次フィードバック\n- 研修テーマの設定\n- 優秀者表彰', 'マニュアル', '品質', '品質,評価,通話,基準'),
('DOC020', '後処理（ACW）入力ガイド', '後処理（ACW）の入力ガイドです。\n\n【ACW入力項目】\n1. 問い合わせカテゴリ（必須）\n2. 対応内容の要約（必須）\n3. 次回アクション（該当時）\n4. エスカレーション有無\n5. VOC（お客様の声）\n\n【入力のポイント】\n- 5W1Hを意識（いつ、誰が、何を、なぜ、どうした）\n- 専門用語OK（社内向け記録のため）\n- 次の対応者が理解できる内容\n\n【例文】\n「カード紛失の届出。本人確認完了、利用停止処理済み。再発行依頼、届出番号XXXXX。1週間程度で届く旨案内。」\n\n【入力時間目安】\n- 通常: 1-2分\n- 複雑な案件: 3-5分\n- ACWは3分以内を目標', 'マニュアル', '業務', 'ACW,後処理,入力,記録'),
('DOC021', 'カード破損・再発行対応手順', 'カード破損時の対応と再発行手順です。\n\n【確認事項】\n1. 破損状況（割れ、曲がり、磁気不良等）\n2. カードの種類（キャッシュ、クレジット、デビット）\n3. 緊急度（すぐに必要か）\n\n【対応手順】\n1. 本人確認（氏名、生年月日、登録電話番号）\n2. 破損カードの利用停止処理\n3. 再発行申請\n4. 届け先住所の確認\n5. 届くまでの案内\n\n【再発行情報】\n- 手数料: 1,100円（税込）\n- 届くまで: 約1週間\n- 届出住所への簡易書留\n\n【RPA連携】\n再発行処理はRPAで自動実行:\n- 処理区分: 再発行\n- カード番号: [CARD_XXXX****]\n- 配送先: 登録住所\n- 優先度: 通常/緊急', 'マニュアル', 'カード', 'カード,破損,再発行,RPA'),
('DOC022', 'RPA連携処理ガイド', 'RPA（ロボティック・プロセス・オートメーション）連携の処理ガイドです。\n\n【RPA対象処理】\n- カード再発行\n- 住所変更\n- 暗証番号再設定\n- 口座開設\n- 利用限度額変更\n- 利用停止\n\n【処理指示フォーマット】\n{\n  "process_type": "カード再発行",\n  "customer_key": "[CUST_KEY]",\n  "card_number": "[CARD_XXXX****]",\n  "delivery_address": "登録住所",\n  "priority": "通常/緊急",\n  "notes": "破損理由等"\n}\n\n【ステータス確認】\n- 処理待ち: RPAキューに登録済み\n- 処理中: RPA実行中\n- 完了: 処理完了\n- エラー: 要手動対応\n\n【注意事項】\n- 個人情報はトークン化して連携\n- エラー時はSVに報告', 'マニュアル', 'RPA', 'RPA,自動化,連携,処理'),

-- スクリプト・テンプレート（10件）
('DOC023', 'オープニングトーク例', '電話応対のオープニングトーク例です。\n\n【基本形】\n「お電話ありがとうございます。SnowBankコールセンター、[名前]でございます。」\n\n【時間帯別】\n午前: 「おはようございます。SnowBankコールセンター、[名前]でございます。」\n午後: 「お電話ありがとうございます。SnowBankコールセンター、[名前]でございます。」\n\n【折り返し時】\n「先ほどはお電話いただきありがとうございました。SnowBankの[名前]でございます。[お客様名]様のお電話でよろしいでしょうか。」\n\n【ポイント】\n- 明るく、はっきりと\n- 名乗りは聞き取りやすく\n- お客様が話し始めるまで待つ', 'スクリプト', '応対', 'オープニング,挨拶,電話'),
('DOC024', 'クロージングトーク例', '電話応対のクロージングトーク例です。\n\n【基本形】\n「本日は私、[名前]が承りました。他にご不明な点はございませんか？（確認後）お電話ありがとうございました。失礼いたします。」\n\n【手続き完了時】\n「お手続きは以上でございます。[手続き内容]につきましては、[期間]ほどお時間をいただきます。他にご質問はございますか？」\n\n【未解決時】\n「確認が取れ次第、[連絡方法]にてご連絡させていただきます。ご連絡先は[番号]でよろしいでしょうか。」\n\n【ポイント】\n- 必ず「他にご質問は」と確認\n- 担当者名を伝える\n- お礼を述べて終了', 'スクリプト', '応対', 'クロージング,終話,電話'),
('DOC025', '待ち時間アナウンス', '保留時のアナウンス例です。\n\n【短時間保留（1分以内）】\n「少々お待ちください。」\n（戻り）「お待たせいたしました。」\n\n【中程度保留（1-3分）】\n「確認いたしますので、少々お待ちいただけますでしょうか。」\n（戻り）「大変お待たせいたしました。」\n\n【長時間保留（3分以上見込み）】\n「確認にお時間がかかりますので、一度お電話を切らせていただき、確認でき次第ご連絡させていただいてもよろしいでしょうか。」\n\n【保留中の経過報告】\n（2分経過時）「もう少々お待ちください。確認中でございます。」\n\n【ポイント】\n- 保留は最大3分を目安\n- 長くなる場合は折り返し提案', 'スクリプト', '応対', '保留,待ち時間,アナウンス'),
('DOC026', '転送時の説明文', '電話転送時の説明文例です。\n\n【担当部署への転送】\n「詳しい担当にお繋ぎいたします。少々お待ちください。」\n（転送後）「お電話代わりました。[部署名]の[名前]でございます。」\n\n【SVへの転送】\n「責任者にお繋ぎいたします。少々お待ちください。」\n\n【転送できない場合】\n「申し訳ございません。ただいま担当が対応中でございます。折り返しお電話させていただいてもよろしいでしょうか。」\n\n【引き継ぎ事項】\n転送前に伝えること:\n- お客様名\n- 問い合わせ内容の概要\n- これまでの対応経緯\n\n【ポイント】\n- たらい回しにしない\n- 経緯を正確に引き継ぐ', 'スクリプト', '応対', '転送,引き継ぎ,電話'),
('DOC027', 'お詫び文言集', 'お詫びの際の文言集です。\n\n【一般的なお詫び】\n「ご不便をおかけして申し訳ございません。」\n「ご迷惑をおかけして大変申し訳ございません。」\n\n【待ち時間へのお詫び】\n「お待たせして申し訳ございません。」\n「長らくお待たせいたしました。」\n\n【システム障害】\n「システムの不具合により、ご不便をおかけして誠に申し訳ございません。」\n\n【対応ミス】\n「私の説明が不十分で、申し訳ございませんでした。」\n「ご案内に誤りがあり、大変申し訳ございませんでした。」\n\n【NGワード】\n×「すみません」→○「申し訳ございません」\n×「ごめんなさい」→○「申し訳ございません」\n×「私のせいではありませんが」→使用禁止', 'スクリプト', 'クレーム', 'お詫び,謝罪,文言'),
('DOC028', '商品案内スクリプト（預金）', '預金商品の案内スクリプトです。\n\n【普通預金】\n「普通預金は、日常のお買い物やお振込みなど、いつでもお使いいただける便利な口座です。キャッシュカードで全国のATMからお引き出しいただけます。」\n\n【定期預金】\n「定期預金は、一定期間お預けいただくことで、普通預金より高い金利が適用されます。期間は1ヶ月から10年まで、まとまった資金の運用にお勧めです。」\n\n【外貨預金】\n「外貨預金は、米ドルやユーロなど外貨で預金いただけます。為替差益を狙える一方、為替リスクもございます。資産分散としてご検討ください。」\n\n【注意事項】\n- 金利は変動する旨を伝える\n- 預金保険の説明（1000万円まで保護）\n- 外貨は為替リスクを必ず説明', 'スクリプト', '商品', '預金,案内,商品説明'),
('DOC029', '商品案内スクリプト（ローン）', 'ローン商品の案内スクリプトです。\n\n【住宅ローン】\n「住宅ローンは、マイホームのご購入や建築資金としてご利用いただけます。変動金利と固定金利をお選びいただけます。事前審査は無料で、最短3日で結果をお知らせします。」\n\n【カードローン】\n「カードローンは、お申込み後、いつでもATMからお借入れいただけます。限度額の範囲内で、繰り返しご利用可能です。返済はATMまたは口座引落しです。」\n\n【教育ローン】\n「教育ローンは、入学金や授業料など、教育資金としてご利用いただけます。在学中は利息のみのお支払いも可能です。」\n\n【注意事項】\n- 審査がある旨を伝える\n- 金利は審査結果による\n- 返済シミュレーションの案内', 'スクリプト', '商品', 'ローン,案内,商品説明'),
('DOC030', '商品案内スクリプト（保険）', '保険商品の案内スクリプトです。\n\n【火災保険】\n「火災保険は、火災だけでなく、風水害や盗難など、住まいに関する様々なリスクをカバーします。住宅ローンをご利用の場合は加入が必須となります。」\n\n【生命保険】\n「生命保険は、万一の際にご家族を守る保障です。お客様のライフステージに合わせて、必要な保障をご提案いたします。」\n\n【医療保険】\n「医療保険は、入院や手術の際の費用をカバーします。日額タイプと一時金タイプがございます。」\n\n【注意事項】\n- 詳細は保険会社の説明を受けていただく\n- 窓口販売は代理店として\n- クーリングオフ制度の説明', 'スクリプト', '商品', '保険,案内,商品説明'),
('DOC031', '苦情対応スクリプト', '苦情対応時のスクリプトです。\n\n【傾聴フェーズ】\n「さようでございますか。それはご不快な思いをされましたね。」\n「おっしゃる通りでございます。」\n「ご指摘いただきありがとうございます。」\n\n【お詫びフェーズ】\n「この度は大変ご不快な思いをさせてしまい、誠に申し訳ございませんでした。」\n\n【解決提案フェーズ】\n「つきましては、[解決策]させていただきたいのですが、いかがでしょうか。」\n\n【クロージング】\n「今後このようなことがないよう、改善に努めてまいります。貴重なご意見をいただきありがとうございました。」\n\n【ポイント】\n- まず聞く、遮らない\n- 言い訳をしない\n- 具体的な解決策を提示', 'スクリプト', 'クレーム', '苦情,クレーム,対応'),
('DOC032', '感謝の言葉バリエーション', '感謝を伝える言葉のバリエーションです。\n\n【お問い合わせへの感謝】\n「お問い合わせいただきありがとうございます。」\n「ご連絡いただきありがとうございます。」\n「お電話いただきありがとうございます。」\n\n【待っていただいたことへの感謝】\n「お待ちいただきありがとうございます。」\n「ご協力いただきありがとうございます。」\n\n【ご意見への感謝】\n「貴重なご意見をいただきありがとうございます。」\n「ご指摘いただきありがとうございます。」\n\n【取引への感謝】\n「いつもご利用いただきありがとうございます。」\n「長年ご愛顧いただきありがとうございます。」\n\n【ポイント】\n- 機械的にならないよう、状況に応じて使い分け\n- 心を込めて伝える', 'スクリプト', '応対', '感謝,お礼,言葉');

-- =============================================================================
-- 5. Semantic View 作成
-- =============================================================================
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'SNOW_CALLCENTER.AI',
  $$
name: SV_INQUIRY_ANALYSIS
description: |
  コールセンターの問い合わせデータを分析するためのセマンティックビュー。
  顧客情報、問い合わせ履歴、通話テキスト、RPA処理状況を統合的に分析可能。

tables:
  - name: CUSTOMER
    description: コールセンターに問い合わせをする顧客情報
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: DIM_CUSTOMER
    synonyms:
      - 顧客
      - お客様
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
        description: 顧客番号
        synonyms:
          - 顧客ID
      - name: CUSTOMER_NAME
        expr: CUSTOMER_NAME
        data_type: VARCHAR
        description: 顧客氏名
        synonyms:
          - 氏名
          - 名前
      - name: CUSTOMER_NAME_MASKED
        expr: CUSTOMER_NAME_MASKED
        data_type: VARCHAR
        description: トークン化された顧客氏名
      - name: GENDER
        expr: GENDER
        data_type: VARCHAR
        description: 性別
      - name: ADDRESS
        expr: ADDRESS
        data_type: VARCHAR
        description: 住所
      - name: CUSTOMER_RANK
        expr: CUSTOMER_RANK
        data_type: VARCHAR
        description: 顧客ランク（一般/シルバー/ゴールド/プラチナ）
        synonyms:
          - 会員ランク
    metrics:
      - name: CUSTOMER_COUNT
        expr: COUNT(DISTINCT CUSTOMER_KEY)
        description: 顧客数

  - name: OPERATOR
    description: コールセンターのオペレーター情報
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: DIM_OPERATOR
    synonyms:
      - オペレーター
      - 担当者
    primary_key:
      columns:
        - OPERATOR_KEY
    dimensions:
      - name: OPERATOR_KEY
        expr: OPERATOR_KEY
        data_type: NUMBER(38,0)
        description: オペレーターサロゲートキー
      - name: OPERATOR_NAME
        expr: OPERATOR_NAME
        data_type: VARCHAR
        description: オペレーター名
      - name: TEAM_NAME
        expr: TEAM_NAME
        data_type: VARCHAR
        description: 所属チーム名
      - name: SKILL_LEVEL
        expr: SKILL_LEVEL
        data_type: VARCHAR
        description: スキルレベル

  - name: CATEGORY
    description: 問い合わせカテゴリ情報
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: DIM_INQUIRY_CATEGORY
    synonyms:
      - カテゴリ
      - 問い合わせ種別
    primary_key:
      columns:
        - CATEGORY_KEY
    dimensions:
      - name: CATEGORY_KEY
        expr: CATEGORY_KEY
        data_type: NUMBER(38,0)
        description: カテゴリサロゲートキー
      - name: CATEGORY_NAME
        expr: CATEGORY_NAME
        data_type: VARCHAR
        description: カテゴリ名
        synonyms:
          - 問い合わせ種別
      - name: PARENT_CATEGORY
        expr: PARENT_CATEGORY
        data_type: VARCHAR
        description: 親カテゴリ
        synonyms:
          - 大分類
      - name: PRIORITY_LEVEL
        expr: PRIORITY_LEVEL
        data_type: VARCHAR
        description: 優先度（通常/高/緊急）
      - name: RPA_ELIGIBLE
        expr: RPA_ELIGIBLE
        data_type: BOOLEAN
        description: RPA処理対象フラグ

  - name: INQUIRY
    description: 顧客からの問い合わせ履歴
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: FACT_INQUIRY
    synonyms:
      - 問い合わせ
      - お問い合わせ
    primary_key:
      columns:
        - INQUIRY_KEY
    dimensions:
      - name: INQUIRY_KEY
        expr: INQUIRY_KEY
        data_type: NUMBER(38,0)
        description: 問い合わせサロゲートキー
      - name: INQUIRY_NUMBER
        expr: INQUIRY_NUMBER
        data_type: VARCHAR
        description: 問い合わせ番号
      - name: CUSTOMER_KEY
        expr: CUSTOMER_KEY
        data_type: NUMBER(38,0)
        description: 顧客キー（FK）
      - name: OPERATOR_KEY
        expr: OPERATOR_KEY
        data_type: NUMBER(38,0)
        description: オペレーターキー（FK）
      - name: CATEGORY_KEY
        expr: CATEGORY_KEY
        data_type: NUMBER(38,0)
        description: カテゴリキー（FK）
      - name: INQUIRY_DATETIME
        expr: INQUIRY_DATETIME
        data_type: TIMESTAMP_NTZ
        description: 問い合わせ日時
        synonyms:
          - 対応日時
      - name: CHANNEL
        expr: CHANNEL
        data_type: VARCHAR
        description: チャネル（電話/メール/チャット/Web）
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
        description: ステータス（完了/対応中/エスカレーション中）
      - name: ESCALATED_FLAG
        expr: ESCALATED_FLAG
        data_type: BOOLEAN
        description: エスカレーションフラグ
      - name: RPA_PROCESSED_FLAG
        expr: RPA_PROCESSED_FLAG
        data_type: BOOLEAN
        description: RPA処理済みフラグ
    facts:
      - name: HANDLE_TIME_SECONDS
        expr: HANDLE_TIME_SECONDS
        data_type: NUMBER(10,0)
        description: 対応時間（秒）
      - name: HOLD_TIME_SECONDS
        expr: HOLD_TIME_SECONDS
        data_type: NUMBER(10,0)
        description: 保留時間（秒）
      - name: SATISFACTION_SCORE
        expr: SATISFACTION_SCORE
        data_type: NUMBER(1,0)
        description: 満足度スコア（1-5）
    metrics:
      - name: INQUIRY_COUNT
        expr: COUNT(INQUIRY_KEY)
        description: 問い合わせ件数
      - name: AVG_HANDLE_TIME
        expr: AVG(HANDLE_TIME_SECONDS)
        description: 平均対応時間（秒）
      - name: AVG_SATISFACTION
        expr: AVG(SATISFACTION_SCORE)
        description: 平均満足度
      - name: ESCALATION_COUNT
        expr: SUM(CASE WHEN ESCALATED_FLAG THEN 1 ELSE 0 END)
        description: エスカレーション件数
      - name: RPA_PROCESSED_COUNT
        expr: SUM(CASE WHEN RPA_PROCESSED_FLAG THEN 1 ELSE 0 END)
        description: RPA処理件数

  - name: TRANSCRIPT
    description: 通話テキストデータ（AmiVoice連携想定）
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: FACT_CALL_TRANSCRIPT
    synonyms:
      - 通話テキスト
      - 通話記録
    primary_key:
      columns:
        - TRANSCRIPT_KEY
    dimensions:
      - name: TRANSCRIPT_KEY
        expr: TRANSCRIPT_KEY
        data_type: NUMBER(38,0)
        description: テキストサロゲートキー
      - name: INQUIRY_KEY
        expr: INQUIRY_KEY
        data_type: NUMBER(38,0)
        description: 問い合わせキー（FK）
      - name: CUSTOMER_KEY
        expr: CUSTOMER_KEY
        data_type: NUMBER(38,0)
        description: 顧客キー（FK）
      - name: CALL_START_DATETIME
        expr: CALL_START_DATETIME
        data_type: TIMESTAMP_NTZ
        description: 通話開始日時
      - name: AI_SUMMARY
        expr: AI_SUMMARY
        data_type: VARCHAR
        description: AI要約
      - name: KEYWORDS
        expr: KEYWORDS
        data_type: VARCHAR
        description: キーワード
    facts:
      - name: CALL_DURATION_SECONDS
        expr: CALL_DURATION_SECONDS
        data_type: NUMBER(10,0)
        description: 通話時間（秒）
      - name: SENTIMENT_SCORE
        expr: SENTIMENT_SCORE
        data_type: NUMBER(3,2)
        description: 感情スコア（0-1）
    metrics:
      - name: TRANSCRIPT_COUNT
        expr: COUNT(TRANSCRIPT_KEY)
        description: 通話テキスト件数
      - name: AVG_CALL_DURATION
        expr: AVG(CALL_DURATION_SECONDS)
        description: 平均通話時間（秒）
      - name: AVG_SENTIMENT
        expr: AVG(SENTIMENT_SCORE)
        description: 平均感情スコア

  - name: RPA_INSTRUCTION
    description: RPA処理指示データ
    base_table:
      database: SNOW_CALLCENTER
      schema: DATA
      table: FACT_RPA_INSTRUCTION
    synonyms:
      - RPA指示
      - 自動処理
    primary_key:
      columns:
        - INSTRUCTION_KEY
    dimensions:
      - name: INSTRUCTION_KEY
        expr: INSTRUCTION_KEY
        data_type: NUMBER(38,0)
        description: 指示サロゲートキー
      - name: INQUIRY_KEY
        expr: INQUIRY_KEY
        data_type: NUMBER(38,0)
        description: 問い合わせキー（FK）
      - name: PROCESS_TYPE
        expr: PROCESS_TYPE
        data_type: VARCHAR
        description: 処理種別
      - name: PRIORITY
        expr: PRIORITY
        data_type: VARCHAR
        description: 優先度
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
        description: ステータス（処理待ち/処理中/完了/エラー）
    metrics:
      - name: RPA_INSTRUCTION_COUNT
        expr: COUNT(INSTRUCTION_KEY)
        description: RPA指示件数
      - name: PENDING_COUNT
        expr: SUM(CASE WHEN STATUS = '処理待ち' THEN 1 ELSE 0 END)
        description: 処理待ち件数
      - name: COMPLETED_COUNT
        expr: SUM(CASE WHEN STATUS = '完了' THEN 1 ELSE 0 END)
        description: 完了件数

relationships:
  - name: INQUIRY_TO_CUSTOMER
    left_table: INQUIRY
    right_table: CUSTOMER
    relationship_columns:
      - left_column: CUSTOMER_KEY
        right_column: CUSTOMER_KEY
    relationship_type: many_to_one
  - name: INQUIRY_TO_OPERATOR
    left_table: INQUIRY
    right_table: OPERATOR
    relationship_columns:
      - left_column: OPERATOR_KEY
        right_column: OPERATOR_KEY
    relationship_type: many_to_one
  - name: INQUIRY_TO_CATEGORY
    left_table: INQUIRY
    right_table: CATEGORY
    relationship_columns:
      - left_column: CATEGORY_KEY
        right_column: CATEGORY_KEY
    relationship_type: many_to_one
  - name: TRANSCRIPT_TO_INQUIRY
    left_table: TRANSCRIPT
    right_table: INQUIRY
    relationship_columns:
      - left_column: INQUIRY_KEY
        right_column: INQUIRY_KEY
    relationship_type: many_to_one
  - name: RPA_TO_INQUIRY
    left_table: RPA_INSTRUCTION
    right_table: INQUIRY
    relationship_columns:
      - left_column: INQUIRY_KEY
        right_column: INQUIRY_KEY
    relationship_type: many_to_one

verified_queries:
  - name: カテゴリ別問い合わせ件数
    question: カテゴリ別の問い合わせ件数を教えて
    use_as_onboarding_question: true
    sql: |
      SELECT
        __category.parent_category,
        __category.category_name,
        COUNT(__inquiry.inquiry_key) AS inquiry_count
      FROM __inquiry
      INNER JOIN __category ON __inquiry.category_key = __category.category_key
      GROUP BY __category.parent_category, __category.category_name
      ORDER BY inquiry_count DESC

  - name: 月別問い合わせ件数推移
    question: 月別の問い合わせ件数の推移を見せて
    use_as_onboarding_question: true
    sql: |
      SELECT
        DATE_TRUNC('MONTH', __inquiry.inquiry_datetime) AS inquiry_month,
        COUNT(__inquiry.inquiry_key) AS inquiry_count,
        ROUND(AVG(__inquiry.handle_time_seconds), 0) AS avg_handle_time,
        ROUND(AVG(__inquiry.satisfaction_score), 2) AS avg_satisfaction
      FROM __inquiry
      GROUP BY DATE_TRUNC('MONTH', __inquiry.inquiry_datetime)
      ORDER BY inquiry_month

  - name: チーム別対応状況
    question: チーム別の対応件数と平均対応時間を教えて
    use_as_onboarding_question: true
    sql: |
      SELECT
        __operator.team_name,
        COUNT(__inquiry.inquiry_key) AS inquiry_count,
        ROUND(AVG(__inquiry.handle_time_seconds), 0) AS avg_handle_time_seconds,
        ROUND(AVG(__inquiry.satisfaction_score), 2) AS avg_satisfaction
      FROM __inquiry
      INNER JOIN __operator ON __inquiry.operator_key = __operator.operator_key
      GROUP BY __operator.team_name
      ORDER BY inquiry_count DESC

  - name: エスカレーション分析
    question: エスカレーション件数をカテゴリ別に集計して
    use_as_onboarding_question: false
    sql: |
      SELECT
        __category.parent_category,
        __category.category_name,
        COUNT(__inquiry.inquiry_key) AS total_count,
        SUM(CASE WHEN __inquiry.escalated_flag THEN 1 ELSE 0 END) AS escalation_count,
        ROUND(SUM(CASE WHEN __inquiry.escalated_flag THEN 1 ELSE 0 END) * 100.0 / COUNT(__inquiry.inquiry_key), 1) AS escalation_rate
      FROM __inquiry
      INNER JOIN __category ON __inquiry.category_key = __category.category_key
      GROUP BY __category.parent_category, __category.category_name
      HAVING SUM(CASE WHEN __inquiry.escalated_flag THEN 1 ELSE 0 END) > 0
      ORDER BY escalation_count DESC

  - name: RPA処理状況
    question: RPA処理のステータス別件数を教えて
    use_as_onboarding_question: false
    sql: |
      SELECT
        __rpa_instruction.process_type,
        __rpa_instruction.status,
        COUNT(__rpa_instruction.instruction_key) AS instruction_count
      FROM __rpa_instruction
      GROUP BY __rpa_instruction.process_type, __rpa_instruction.status
      ORDER BY __rpa_instruction.process_type, __rpa_instruction.status

  - name: 顧客別問い合わせ履歴
    question: 顧客番号C000001の問い合わせ履歴を教えて
    use_as_onboarding_question: false
    sql: |
      SELECT
        __customer.customer_number,
        __customer.customer_name_masked,
        __inquiry.inquiry_datetime,
        __category.category_name,
        __inquiry.status,
        __inquiry.satisfaction_score
      FROM __inquiry
      INNER JOIN __customer ON __inquiry.customer_key = __customer.customer_key
      INNER JOIN __category ON __inquiry.category_key = __category.category_key
      WHERE __customer.customer_number = 'C000001'
      ORDER BY __inquiry.inquiry_datetime DESC
$$
);

-- =============================================================================
-- 6. Cortex Search Service 作成
-- =============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE SNOW_CALLCENTER.AI.CALLCENTER_DOCUMENTS_CSS
    ON CONTENT
    ATTRIBUTES TITLE, DOCUMENT_TYPE, CATEGORY
    WAREHOUSE = SNOW_CALLCENTER_WH
    TARGET_LAG = '1 hour'
    COMMENT = 'コールセンター業務ドキュメント（FAQ、マニュアル、スクリプト）検索サービス'
    AS (
        SELECT
            DOCUMENT_ID,
            TITLE,
            CONTENT,
            DOCUMENT_TYPE,
            CATEGORY,
            KEYWORDS,
            VERSION
        FROM SNOW_CALLCENTER.DATA.CALL_CENTER_DOCUMENT
    );

-- =============================================================================
-- 7. Cortex Agent 作成
-- =============================================================================
CREATE OR REPLACE AGENT SNOW_CALLCENTER.AI.CALLCENTER_SUPPORT_AGENT
  COMMENT = 'このエージェントはSnowBankコールセンターの業務支援エージェントです。顧客情報・問い合わせ履歴の分析、FAQ・マニュアルの検索に対応します。'
  PROFILE = '{"display_name": "Call Center Support Agent"}'
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
       - 可能であればグラフで可視化
    4. 個人情報の取り扱い：
       - 顧客の個人情報はトークン化された形式（[NAME_1], [CARD_XXXX]等）で表示
       - 生の個人情報は表示しない
    5. 免責事項：
       - 回答の末尾に以下を記載
       - "【免責事項】本回答はSnowflake Intelligenceによるデモンストレーション目的で生成されたものです。SnowBankは架空の金融機関であり、表示されるデータはすべてサンプルデータです。"
  orchestration: |
    1. ユーザーからの質問を受け取り、質問の意図を分析する
    2. 質問の内容に応じて、適切なツールを選択：
       - 構造化データ（顧客情報、問い合わせ履歴、RPA状況など）に関する質問 → CustomerAnalyst
       - 業務マニュアル、FAQ、スクリプトに関する質問 → DocumentSearch
    3. ツールの使い分け基準：
       - 「〇〇の件数」「平均」「推移」など数値を求める質問 → CustomerAnalyst
       - 「手順」「方法」「対応方法」「スクリプト」に関する質問 → DocumentSearch
       - 複合的な質問の場合は、必要に応じて複数のツールを使用
  sample_questions:
    - question: "カテゴリ別の問い合わせ件数を教えて"
      answer: "問い合わせデータからカテゴリ別の件数を集計します。"
    - question: "昨年のエスカレーション件数は？"
      answer: "問い合わせデータから昨年（2024年）のエスカレーション件数を集計します。"
    - question: "カード紛失時の対応手順を教えて"
      answer: "業務マニュアルからカード紛失時の対応手順をご案内します。"
    - question: "クレーム対応のスクリプトを教えて"
      answer: "苦情対応スクリプトをご案内します。"
    - question: "顧客C000001の問い合わせ履歴を確認して、適切な対応方法を提案して"
      answer: "顧客の問い合わせ履歴を確認し、マニュアルに基づいて対応方法を提案します。"

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: CustomerAnalyst
      description: "顧客情報、問い合わせ履歴、通話テキスト、RPA処理状況などの構造化データに関する質問に回答します"

  - tool_spec:
      type: cortex_search
      name: DocumentSearch
      description: "FAQ、業務マニュアル、対応スクリプトなどのドキュメントを検索します"

tool_resources:
  CustomerAnalyst:
    semantic_view: "SNOW_CALLCENTER.AI.SV_INQUIRY_ANALYSIS"
  DocumentSearch:
    name: "SNOW_CALLCENTER.AI.CALLCENTER_DOCUMENTS_CSS"
    max_results: "5"
$$;

-- =============================================================================
-- 8. 検証
-- =============================================================================
SELECT 'DIM_CUSTOMER' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOW_CALLCENTER.DATA.DIM_CUSTOMER
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM SNOW_CALLCENTER.DATA.DIM_PRODUCT
UNION ALL SELECT 'DIM_OPERATOR', COUNT(*) FROM SNOW_CALLCENTER.DATA.DIM_OPERATOR
UNION ALL SELECT 'DIM_INQUIRY_CATEGORY', COUNT(*) FROM SNOW_CALLCENTER.DATA.DIM_INQUIRY_CATEGORY
UNION ALL SELECT 'FACT_INQUIRY', COUNT(*) FROM SNOW_CALLCENTER.DATA.FACT_INQUIRY
UNION ALL SELECT 'FACT_CALL_TRANSCRIPT', COUNT(*) FROM SNOW_CALLCENTER.DATA.FACT_CALL_TRANSCRIPT
UNION ALL SELECT 'FACT_RPA_INSTRUCTION', COUNT(*) FROM SNOW_CALLCENTER.DATA.FACT_RPA_INSTRUCTION
UNION ALL SELECT 'CALL_CENTER_DOCUMENT', COUNT(*) FROM SNOW_CALLCENTER.DATA.CALL_CENTER_DOCUMENT;

SHOW SEMANTIC VIEWS IN SCHEMA SNOW_CALLCENTER.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOW_CALLCENTER.AI;
SHOW AGENTS IN SCHEMA SNOW_CALLCENTER.AI;

-- =============================================================================
-- 9. 権限付与（必要に応じてコメント解除）
-- =============================================================================
-- SET TARGET_ROLE = 'CALLCENTER_USER';
-- GRANT USAGE ON DATABASE SNOW_CALLCENTER TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON SCHEMA SNOW_CALLCENTER.DATA TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON SCHEMA SNOW_CALLCENTER.AI TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT SELECT ON ALL TABLES IN SCHEMA SNOW_CALLCENTER.DATA TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA SNOW_CALLCENTER.AI TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON CORTEX SEARCH SERVICE SNOW_CALLCENTER.AI.CALLCENTER_DOCUMENTS_CSS TO ROLE IDENTIFIER($TARGET_ROLE);
-- GRANT USAGE ON AGENT SNOW_CALLCENTER.AI.CALLCENTER_SUPPORT_AGENT TO ROLE IDENTIFIER($TARGET_ROLE);
