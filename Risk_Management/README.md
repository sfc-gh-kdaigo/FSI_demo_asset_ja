# 🏦 SnowBank 信用リスク管理 デモ環境

金融機関の信用リスク管理業務を支援する **Snowflake Intelligence** デモ環境です。

## 🎯 概要

このデモは、架空の金融機関「SnowBank（スノーバンク）」のリスク管理部門を想定し、以下を実現します：

- **内部リスク指標（EL/UL/経済資本）の分析**
- **規制資本（RWA）のモニタリング**
- **リスク管理ドキュメントのAI検索**
- **自然言語によるリスクデータ分析**

## 🏗️ システム構成

```
📊 リスク管理部門
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                        Snowflake                            │
│                                                             │
│  ┌──────────────────┐    ┌────────────────────────────────┐│
│  │   内部リスク計測   │    │        Cortex Agent           ││
│  │  (EL/UL/EC)      │◄──│  ┌──────────────┬────────────┐ ││
│  │  FACT_INTERNAL   │    │  │Internal     │Regulatory │ ││
│  │     _RISK        │    │  │RiskAnalyst  │RiskAnalyst│ ││
│  └──────────────────┘    │  │(Text-to-SQL)│(Text-to-SQL)│ ││
│  ┌──────────────────┐    │  └──────────────┴────────────┘ ││
│  │   規制資本計算    │◄──│  ┌────────────────────────────┐ ││
│  │  (RWA/RW)        │    │  │    RiskDocumentSearch     │ ││
│  │  FACT_REGULATORY │    │  │         (RAG検索)          │ ││
│  │     _RISK        │    │  └────────────────────────────┘ ││
│  └──────────────────┘    └────────────────────────────────┘│
│  ┌──────────────────┐                ▲                     │
│  │ リスク管理ドキュメント│────────────────┘                     │
│  │  RISK_DOCUMENT   │                                      │
│  │  (規程/マニュアル)  │                                      │
│  └──────────────────┘                                      │
└─────────────────────────────────────────────────────────────┘
             │
             ▼
    ┌────────────────┐
    │  📋 月次レポート  │
    │  リスク管理委員会 │
    └────────────────┘
```

## 📊 データモデル

| テーブル名 | 件数 | 用途 |
|:---|---:|:---|
| DIM_RATING | 15 | 内部格付マスタ（AAA〜D、正常先〜破綻先） |
| DIM_INDUSTRY | 30 | 業種マスタ（日銀業種分類ベース） |
| DIM_DEPARTMENT | 20 | 部門マスタ（営業部門/管理部門） |
| DIM_PRODUCT | 30 | 商品マスタ（証書貸付/当座貸越等） |
| DIM_COUNTERPARTY | 500 | 取引先マスタ |
| FACT_LOAN_DETAIL | 3,000 | 貸出明細ファクト |
| FACT_INTERNAL_RISK | 3,000 | 内部リスク計測ファクト（EL/UL/EC） |
| FACT_REGULATORY_RISK | 3,000 | 規制資本ファクト（RWA） |
| RISK_DOCUMENT | 40 | リスク管理ドキュメント |

ER図は `er_diagram_risk.html` をブラウザで開いてご確認ください。

## 🤖 AI コンポーネント

### Semantic View: `SV_INTERNAL_RISK_ANALYSIS`
内部リスク指標（EL/UL/経済資本/PD/LGD/EAD）の分析用セマンティックビュー。

### Semantic View: `SV_REGULATORY_RISK_ANALYSIS`
規制資本指標（RWA/リスクウェイト/エクスポージャー区分）の分析用セマンティックビュー。

### Cortex Search Service: `RISK_DOCUMENTS_CSS`
リスク管理規程、バーゼル規制解説、業務マニュアル、用語集の検索サービス。

### Cortex Agent: `RISK_MANAGEMENT_AGENT`
3つのツールを持つ統合エージェント：
- **InternalRiskAnalyst**: 内部リスク指標分析（Text-to-SQL）
- **RegulatoryRiskAnalyst**: 規制資本分析（Text-to-SQL）
- **RiskDocumentSearch**: ドキュメント検索（RAG）

## 🚀 セットアップ手順

### 1️⃣ 前提条件
- Snowflake アカウント（Cortex AI 機能が有効）
- ACCOUNTADMIN ロール

### 2️⃣ 実行方法

```sql
-- Snowsight SQL Worksheet で risk_setup.sql を実行
```

または Snowflake CLI:

```bash
snow sql -f risk_setup.sql
```

### 3️⃣ 確認

```sql
-- データ件数確認
SELECT 'DIM_RATING' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM SNOW_RISK.DATA.DIM_RATING
UNION ALL SELECT 'FACT_LOAN_DETAIL', COUNT(*) FROM SNOW_RISK.DATA.FACT_LOAN_DETAIL
UNION ALL SELECT 'FACT_INTERNAL_RISK', COUNT(*) FROM SNOW_RISK.DATA.FACT_INTERNAL_RISK
UNION ALL SELECT 'FACT_REGULATORY_RISK', COUNT(*) FROM SNOW_RISK.DATA.FACT_REGULATORY_RISK
UNION ALL SELECT 'RISK_DOCUMENT', COUNT(*) FROM SNOW_RISK.DATA.RISK_DOCUMENT;

-- AI コンポーネント確認
SHOW SEMANTIC VIEWS IN SCHEMA SNOW_RISK.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOW_RISK.AI;
SHOW AGENTS IN SCHEMA SNOW_RISK.AI;
```

## 💬 質問例

### 📈 内部リスク分析（InternalRiskAnalyst）
- 「部門別のELとULを集計して」
- 「格付がBBB以下のエクスポージャーを見せて」
- 「業種別で経済資本が大きい順に並べて」
- 「PD5%以上の貸出先一覧」
- 「ELとULの合計を教えて」

### 📊 規制資本分析（RegulatoryRiskAnalyst）
- 「エクスポージャー区分別のRWAを教えて」
- 「リスクウェイト100%以上の貸出を抽出して」
- 「標準的手法とIRB手法のRWA比較」
- 「部門別の平均リスクウェイトは？」
- 「信用RWAの合計を教えて」

### 📚 ドキュメント検索（RiskDocumentSearch）
- 「ELの計算式を教えて」
- 「格付見直しのプロセスは？」
- 「バーゼルIIIファイナライズの概要」
- 「信用リスク削減手法とは」
- 「大口与信管理のルール」

### 🔄 複合分析
- 「業種別のELを集計し、ELとは何かも説明して」
- 「RWAの大きい部門を特定し、リスクウェイトの計算方法も教えて」

## 📖 用語集

| 用語 | 英語 | 説明 |
|:---|:---|:---|
| EL | Expected Loss | 期待損失。通常予想される損失額（EAD×PD×LGD） |
| UL | Unexpected Loss | 非期待損失。ストレス時の追加損失 |
| EC | Economic Capital | 経済資本。リスクをカバーするために必要な資本 |
| PD | Probability of Default | デフォルト確率 |
| LGD | Loss Given Default | デフォルト時損失率 |
| EAD | Exposure at Default | デフォルト時エクスポージャー |
| RWA | Risk Weighted Assets | リスク加重資産。自己資本比率の分母 |
| IRB | Internal Ratings-Based | 内部格付手法 |
| SA | Standardized Approach | 標準的手法 |

## 📁 ファイル構成

```
Risk_Management/
├── README.md               # 本ファイル
├── risk_setup.sql          # 環境構築 SQL
├── er_diagram_risk.html    # ER図（ブラウザ表示用）
└── plan.md                 # 設計ドキュメント
```

## ⚠️ 免責事項

- このデモはSnowflake Intelligenceの機能紹介を目的としています
- SnowBankは架空の金融機関です
- 表示されるデータはすべてサンプルデータです
- 実際のリスク管理業務には使用しないでください

## 📚 参考リンク

- [Snowflake Cortex AI](https://docs.snowflake.com/en/guides-overview-ai-features)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [Cortex Agent](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [バーゼルIII（金融庁）](https://www.fsa.go.jp/policy/basel_ii/index.html)
