# 📞 SnowBank コールセンター デモ環境

金融機関のコールセンター業務を支援する **Snowflake Intelligence** デモ環境です。

## 🎯 概要

このデモは、架空の金融機関「SnowBank（スノーバンク）」のコールセンターを想定し、以下を実現します：

- **顧客情報・問い合わせ履歴の即時照会**
- **FAQ・マニュアルのAI検索**
- **通話テキストからの処理判断（AmiVoice連携想定）**
- **RPA連携用の処理指示出力**

## 🏗️ システム構成

```
📞 顧客通話
    │
    ▼
🎤 AmiVoice (音声認識) ─────────┐
                               │ 通話テキスト
                               ▼
┌─────────────────────────────────────────────────┐
│                   Snowflake                      │
│  ┌─────────────┐    ┌─────────────────────────┐ │
│  │ 通話テキスト  │◄──│      Cortex Agent      │ │
│  │   (FACT)    │    │  ┌─────────┬─────────┐ │ │
│  └─────────────┘    │  │Analyst  │ Search  │ │ │
│  ┌─────────────┐    │  │(SQL生成)│(RAG検索)│ │ │
│  │ マニュアル   │───▶│  └─────────┴─────────┘ │ │
│  │   (DOC)     │    └───────────┬─────────────┘ │
│  └─────────────┘                │               │
│  ┌─────────────┐                │               │
│  │  RPA指示    │◄───────────────┘               │
│  │   (FACT)    │                                │
│  └─────────────┘                                │
└────────────┬────────────────────────────────────┘
             │ トークン化済みデータ
             ▼
    ┌────────────────┐
    │  📋 Salesforce  │ ─────▶ 🤖 RPA (自動処理)
    │   (承認/確認)   │
    └────────────────┘
```

## 📊 データモデル

| テーブル名 | 件数 | 用途 |
|:---|---:|:---|
| DIM_CUSTOMER | 200 | 顧客マスタ（トークン化カラム含む） |
| DIM_PRODUCT | 20 | 商品・サービスマスタ |
| DIM_OPERATOR | 30 | オペレーターマスタ |
| DIM_INQUIRY_CATEGORY | 25 | 問い合わせカテゴリマスタ |
| FACT_INQUIRY | 2,000 | 問い合わせファクト |
| FACT_CALL_TRANSCRIPT | 500 | 通話テキスト（AmiVoice連携想定） |
| FACT_RPA_INSTRUCTION | 300 | RPA処理指示 |
| CALL_CENTER_DOCUMENT | 32 | FAQ・マニュアル・スクリプト |

ER図は `er_diagram_callcenter.html` をブラウザで開いてご確認ください。

## 🤖 AI コンポーネント

### Semantic View: `SV_INQUIRY_ANALYSIS`
問い合わせデータの分析用セマンティックビュー。Verified Query 付き。

### Cortex Search Service: `CALLCENTER_DOCUMENTS_CSS`
FAQ、マニュアル、対応スクリプトの検索サービス。

### Cortex Agent: `CALLCENTER_SUPPORT_AGENT`
2つのツールを持つ統合エージェント：
- **CustomerAnalyst**: 構造化データ分析（Text-to-SQL）
- **DocumentSearch**: ドキュメント検索（RAG）

## 🚀 セットアップ手順

### 1️⃣ 前提条件
- Snowflake アカウント（Cortex AI 機能が有効）
- ACCOUNTADMIN ロール

### 2️⃣ 実行方法

```sql
-- Snowsight SQL Worksheet で callcenter_setup.sql を実行
```

または Snowflake CLI:

```bash
snow sql -f callcenter_setup.sql
```

### 3️⃣ 確認

```sql
-- データ件数確認
SELECT 'DIM_CUSTOMER' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOW_CALLCENTER.DATA.DIM_CUSTOMER
UNION ALL SELECT 'FACT_INQUIRY', COUNT(*) FROM SNOW_CALLCENTER.DATA.FACT_INQUIRY
UNION ALL SELECT 'CALL_CENTER_DOCUMENT', COUNT(*) FROM SNOW_CALLCENTER.DATA.CALL_CENTER_DOCUMENT;

-- AI コンポーネント確認
SHOW SEMANTIC VIEWS IN SCHEMA SNOW_CALLCENTER.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOW_CALLCENTER.AI;
SHOW AGENTS IN SCHEMA SNOW_CALLCENTER.AI;
```

## 💬 質問例

### 📈 データ分析（CustomerAnalyst）
- 「カテゴリ別の問い合わせ件数を教えて」
- 「昨年1年間の問い合わせ件数とエスカレーション発生件数、およびエスカレーション率を抽出して可視化して」
- 「チーム別の平均対応時間を集計して」
- 「顧客C000001の問い合わせ履歴を見せて」
- 「RPA処理待ちの件数を教えて」

### 📚 ドキュメント検索（DocumentSearch）
- 「社内で定義されている上長へのエスカレーション基準を解説して」
- 「クレーム対応のスクリプトを教えて」
- 「高齢者対応で気をつけることは？」
- 「振込手数料について説明して」

### 🔄 複合分析
- 「顧客C000001の問い合わせ履歴を確認して、適切な対応方法を提案して」
- 「通話内容から必要な処理を判断して、RPA指示を作成して」

## 🔐 トークン化（個人情報マスキング）

個人情報は以下のルールでトークン化されます：

| データ種別 | トークン形式 | 例 |
|:---|:---|:---|
| 氏名 | `[NAME_n]` | [NAME_1] |
| カード番号 | `[CARD_XXXXnnnn]` | [CARD_XXXX1234] |
| 口座番号 | `[ACCT_XXXXnnnn]` | [ACCT_XXXX5678] |
| 電話番号 | `[PHONE_n]` | [PHONE_1] |
| 住所 | `[ADDR_n]` | [ADDR_1] |

## 📁 ファイル構成

```
Call_Center/
├── README.md                    # 本ファイル
├── callcenter_setup.sql         # 環境構築 SQL
└── er_diagram_callcenter.html   # ER図（ブラウザ表示用）
```

## ⚠️ 免責事項

- このデモはSnowflake Intelligenceの機能紹介を目的としています
- SnowBankは架空の金融機関です
- 表示されるデータはすべてサンプルデータです
- 実際の業務判断には使用しないでください

## 📚 参考リンク

- [Snowflake Cortex AI](https://docs.snowflake.com/en/guides-overview-ai-features)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [Cortex Agent](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent)
