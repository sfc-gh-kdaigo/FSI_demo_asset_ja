# Credit Management AI Agent MVP

Snowflake Cortex Agent を活用した、ネット銀行向け与信管理 AI エージェントの MVP です。

## 構成

```
Credit_Management/setup/
  pdf/                              ... サンプル PDF（与信規程・業界レポート）
    credit_policy_guideline.pdf
    industry_report_2024.pdf
  01_db_setup.sql                   ... 環境構築・テーブル作成・サンプルデータ
  02_search_setup.sql               ... PDF アップロード・パース・Cortex Search
  03_sv_setup.sql                   ... Semantic View 作成
  04_sproc_setup.sql                ... Stored Procedure（Agent カスタムツール）
  05_agent_setup.sql                ... Cortex Agent 作成 & Intelligence 公開手順
  generate_sample_pdfs.py           ... PDF 再生成用スクリプト（通常は不要）
```

## 前提条件

- Snowflake アカウント（Cortex AI が利用可能なリージョン）
- `ACCOUNTADMIN` ロール（または同等権限）
- [SnowSQL](https://docs.snowflake.com/en/user-guide/snowsql) または [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/index)（PDF アップロード用）

## セットアップ手順

### Step 1: テーブル・サンプルデータ作成

Snowsight ワークシートまたは SnowSQL で実行:

```sql
-- 01_db_setup.sql を全文実行
```

### Step 2: PDF アップロード & Cortex Search 作成

**PDF のアップロードは SnowSQL / snow CLI が必要です**（Snowsight の PUT は非対応）。

```bash
cd Credit_Management/setup

snowsql -q "PUT file://pdf/credit_policy_guideline.pdf @CREDIT_MGMT_DB.DOCUMENTS.credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
snowsql -q "PUT file://pdf/industry_report_2024.pdf @CREDIT_MGMT_DB.DOCUMENTS.credit_docs AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
snowsql -q "ALTER STAGE CREDIT_MGMT_DB.DOCUMENTS.credit_docs REFRESH;"
```

その後、`02_search_setup.sql` の Step 2 以降を Snowsight で実行してください。

### Step 3: Semantic View 作成

```sql
-- 03_sv_setup.sql を全文実行
```

### Step 4: Stored Procedure 作成

```sql
-- 04_sproc_setup.sql を全文実行
```

### Step 5: Agent 作成

```sql
-- 05_agent_setup.sql を全文実行
```

### Step 6: Snowflake CoWork 公開（任意・GUI操作）

`05_agent_setup.sql` 内の Step 3 コメントに記載の手順で、Snowsight の GUI から Intelligence を公開します。

## Agent のツール構成

| # | ツール名 | 種別 | 用途 |
|---|---------|------|------|
| 1 | credit_analysis_sv | Semantic View | 融資残高・財務指標・ポートフォリオ分析 |
| 2 | credit_review_search | Cortex Search | 審査レポート・面談記録の検索 |
| 3 | credit_policy_search | Cortex Search | 与信規程・業界レポートの照会 |
| 4 | calculate_credit_score | Stored Procedure | 信用スコア算出（0-100点） |
| 5 | generate_review_report | Stored Procedure | 審査レポートドラフト生成 |
| 6 | send_email | Stored Procedure | メール送信 |
| 7 | get_document_download_url | Stored Procedure | PDF ダウンロード URL 生成 |

## 動作確認

```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'CREDIT_MGMT_DB.AGENT.CREDIT_MANAGEMENT_AGENT',
  '融資残高が大きい企業トップ5を教えてください'
);
```

## 環境のカスタマイズ

各 SQL ファイル冒頭の `SET` 変数を変更することで、DB名やウェアハウス名をカスタマイズできます:

```sql
SET DB_NAME    = 'CREDIT_MGMT_DB';
SET WH_NAME    = 'CREDIT_MGMT_WH';
SET ADMIN_ROLE = 'ACCOUNTADMIN';
```

## PDF の再生成（任意）

`pdf/` 内の PDF を再生成したい場合:

```bash
pip install fpdf2
python Credit_Management/setup/generate_sample_pdfs.py
```

## 注意事項

- 全ての企業名・財務データは架空のデモ用データです
- `CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'` が `01_db_setup.sql` で設定されます
- Agent のモデルは `claude-sonnet-4-6` を使用しています
