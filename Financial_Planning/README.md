# 🏦 信託銀行 財務企画部 AIアシスタント

大手信託銀行の財務企画部における **BPR（業務改革）プロジェクト** のデモ環境です。
**Snowflake Intelligence** のAIエージェントが、予算管理・収益分析・決算業務・規程照会をワンストップで支援します。

---

## 🎯 概要

架空の大手信託銀行「SnowBank Trust」の財務企画部を想定し、以下を実現します：

- **財務会計分析**: 仕訳明細・GL残高・予算消化率の即時照会
- **管理会計分析**: 事業別損益・社内仕切り（TP）・財管差の分析
- **規程・通達検索**: 行内規定集・経費精算ガイドラインのAI検索（RAG）
- **決算資料検索**: 過去の決算資料・報告書テンプレートのAI検索（RAG）

---

## 🏗️ システム構成

```
┌──────────────────────────────────────────────────────────┐
│                  Cortex Agent                            │
│           「財務 AI アシスタント」                         │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────┐             │
│  │ 財務会計分析      │  │ 管理会計分析      │             │
│  │ (Cortex Analyst) │  │ (Cortex Analyst) │             │
│  │                  │  │                  │             │
│  │ ・仕訳明細検索   │  │ ・事業別PL分析   │             │
│  │ ・GL残高照会     │  │ ・財管差分析     │             │
│  │ ・予算消化率分析 │  │ ・社内仕切り計算 │             │
│  │ ・決算補正一覧   │  │ ・部門損益比較   │             │
│  └──────────────────┘  └──────────────────┘             │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────┐             │
│  │ 規程・通達検索    │  │ 決算資料検索      │             │
│  │ (Cortex Search)  │  │ (Cortex Search)  │             │
│  │                  │  │                  │             │
│  │ ・行内規定PDF    │  │ ・過去決算資料   │             │
│  │ ・経費精算GL     │  │ ・報告書テンプレ │             │
│  │ ・会計処理通達   │  │ ・当局提出書類   │             │
│  └──────────────────┘  └──────────────────┘             │
└──────────────────────────────────────────────────────────┘
```

---

## 📊 データモデル

### 財務会計ドメイン

| テーブル名 | 種別 | 用途 |
|:---|:---|:---|
| FACT_JOURNAL_ENTRIES | ファクト | 仕訳明細（通常/決算補正/連結消去） |
| FACT_BUDGET | ファクト | 予算データ（当初/修正） |
| DIM_ACCOUNT | ディメンション | 勘定科目マスタ（16科目） |
| DIM_DEPARTMENT | ディメンション | 部門マスタ（10部門） |
| DIM_PERIOD | ディメンション | 会計期間マスタ（2025年度12ヶ月） |

### 管理会計ドメイン

| テーブル名 | 種別 | 用途 |
|:---|:---|:---|
| FACT_SEGMENT_PL | ファクト | 事業別損益（財務/管理/財管差） |
| FACT_TRANSFER_PRICING | ファクト | 社内仕切り明細（金利/為替/手数料） |
| DIM_BUSINESS_SEGMENT | ディメンション | 事業セグメントマスタ（5区分） |

### 非構造化データ（PDF）

| テーブル名 | 用途 |
|:---|:---|
| REGULATION_CHUNKS | 規程・通達PDFのチャンクテーブル |
| FINANCIAL_REPORTS_CHUNKS | 決算資料PDFのチャンクテーブル |

---

## 🤖 AI コンポーネント

### Semantic View（CREATE SEMANTIC VIEW）

| オブジェクト | ドメイン | 主な機能 |
|:---|:---|:---|
| `SV_FINANCIAL_ACCOUNTING` | 財務会計 | 仕訳照会、予算消化率、決算補正管理 |
| `SV_MANAGEMENT_ACCOUNTING` | 管理会計 | セグメントPL、財管差、社内仕切り分析 |

セマンティックビューは YAML ではなく **`CREATE SEMANTIC VIEW`（SQL DDL）** で定義。
`WITH SYNONYMS` による日本語同義語と `AI_SQL_GENERATION` 句によるドメイン特化の SQL 生成指示を活用。

### Cortex Search Service

| サービス | 検索対象 |
|:---|:---|
| `REGULATION_SEARCH_SERVICE` | 行内規定PDF・経費精算ガイドライン |
| `FINANCIAL_REPORTS_SEARCH_SERVICE` | 過去決算資料・報告書テンプレート |

### Cortex Agent: `BANK_FINANCE_AGENT`

4つのツールを持つ統合エージェント：

| ツール | 種別 | ドメイン |
|:---|:---|:---|
| **財務会計分析** | Cortex Analyst (Text-to-SQL) | 仕訳・GL・予算 |
| **管理会計分析** | Cortex Analyst (Text-to-SQL) | 事業別損益・TP・財管差 |
| **規程検索** | Cortex Search (RAG) | 規程・通達PDF |
| **決算資料検索** | Cortex Search (RAG) | 決算資料・報告書PDF |

### ドメイン分離の根拠

| 観点 | 財務会計 | 管理会計 |
|:---|:---|:---|
| 目的 | 制度準拠（正確な仕訳・開示） | 意思決定支援（事業別損益の把握） |
| データ粒度 | 仕訳明細・勘定残高 | セグメント別集計・TP配賦 |
| SQLパターン | GL照会・予算対比・補正一覧 | セグメントJOIN・TP計算・財管差 |

---

## 🚀 セットアップ手順

### 1️⃣ 前提条件

- Snowflake アカウント（Enterprise 以上、Cortex AI が利用可能なリージョン）
- ACCOUNTADMIN ロール
- Snowflake Intelligence が利用可能であること

### 2️⃣ setup.sql の実行（Step 1〜5）

```sql
-- Snowsight SQL Worksheet で setup.sql の Step 1〜5 を実行
```

または Snowflake CLI:

```bash
snow sql -f setup.sql
```

これにより以下が自動作成されます：
- ロール・ウェアハウス・データベース・スキーマ
- 全テーブル ＋ サンプルデータ
- セマンティックビュー × 2

### 3️⃣ サンプル PDF の生成・アップロード

```bash
pip install fpdf2
python generate_sample_pdfs.py
```

生成される PDF（`pdfs/` フォルダ）：

| ファイル名 | 内容 |
|:---|:---|
| `regulation_expense_policy.pdf` | 経費精算規程 |
| `regulation_accounting_standards.pdf` | 会計処理基準通達 |
| `financial_report_2024q4.pdf` | 2024年度Q4決算概要 |
| `financial_report_2025q1.pdf` | 2025年度Q1決算概要 |

Snowsight → Catalog → `BANK_BPR_DB` → `ANALYTICS` → Stages → `DOCUMENTS_STAGE` → **[+ Files]** でアップロード

### 4️⃣ setup.sql の続行（Step 6〜8）

PDF アップロード後、`setup.sql` の Step 6（Cortex Search Service）以降を続けて実行。
Step 8 で `CREATE AGENT` により Agent が自動作成されます。

### 5️⃣ 確認

```sql
-- データ件数確認
SELECT 'FACT_JOURNAL_ENTRIES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM BANK_BPR_DB.ANALYTICS.FACT_JOURNAL_ENTRIES
UNION ALL SELECT 'FACT_BUDGET', COUNT(*) FROM BANK_BPR_DB.ANALYTICS.FACT_BUDGET
UNION ALL SELECT 'FACT_SEGMENT_PL', COUNT(*) FROM BANK_BPR_DB.ANALYTICS.FACT_SEGMENT_PL
UNION ALL SELECT 'FACT_TRANSFER_PRICING', COUNT(*) FROM BANK_BPR_DB.ANALYTICS.FACT_TRANSFER_PRICING;

-- AI コンポーネント確認
SHOW SEMANTIC VIEWS IN SCHEMA BANK_BPR_DB.ANALYTICS;
SHOW CORTEX SEARCH SERVICES IN SCHEMA BANK_BPR_DB.ANALYTICS;
SHOW AGENTS IN SCHEMA BANK_BPR_DB.ANALYTICS;
```

### 6️⃣ Streamlit アプリのデプロイ（任意）

1. Snowsight → Streamlit → **+ Streamlit App**
2. データベース: `BANK_BPR_DB`、スキーマ: `ANALYTICS`、ウェアハウス: `BANK_BPR_WH` を選択
3. `streamlit_app.py` の内容をエディタに貼り付け
4. パッケージタブで `environment.yml` の依存関係を追加

---

## 💬 質問例

### 📈 財務会計分析

- 「今四半期の**営業経費の予算消化率**を部門別に表示してください」
- 「今期の**決算補正仕訳**の一覧を金額降順で表示してください」
- 「前年同期比で**有価証券利息**の推移を月次で見せてください」
- 「**貸出金利息**の月別推移をグラフで表示して」

### 📊 管理会計分析

- 「**リテール事業と市場事業**の今期PLを比較してください」
- 「**財管差**が大きいセグメントと主要勘定を教えてください」
- 「**社内仕切り**の影響額をセグメント別に見せてください」
- 「2025年度の**事業セグメント別損益**を一覧で表示して」

### 📚 規程・資料検索

- 「旅費精算で**グリーン車利用**が認められる条件は？」
- 「**海外送金手数料**の正しい勘定科目は？」
- 「前期の決算資料でリテール事業についてどう記載されていた？」

### 🔄 複合分析（マルチツール）

- 「法人営業部の旅費交通費が**予算を超過**しているか確認し、グリーン車利用の**規程上のルール**も教えてください」
- 「市場事業の今期の**業績概要**をまとめて、前回の決算資料での記載内容を踏まえて**報告書ドラフト**を作成してください」

---

## ✨ 解決する業務課題

| 😫 これまで | 😊 AIアシスタントなら |
|:---|:---|
| 決算ピーク時に集計・加工の手作業 | **チャットで質問するだけで仕訳分析が完了** |
| 原因不明の財管差を手動で追跡 | **財管差の主要因を自動特定・説明** |
| Excelで予算消化率を手計算 | **「予算消化率を出して」で即座に集計** |
| 行内規定を都度検索して妥当性確認 | **規程名・条項番号付きで根拠を回答** |
| 報告書作成にExcel加工・グラフ作成 | **分析結果を統合し日本語ドラフトを自動生成** |

---

## 🔐 セキュリティ・ガバナンス

| 項目 | 方針 |
|:---|:---|
| データ境界 | 全データは Snowflake のガバナンス境界内で処理 |
| ロール設計 | `BANK_BPR_ADMIN_ROLE`（管理者）→ `BANK_BPR_AGENT_ROLE`（Agent実行） |
| 最小権限 | Agent ロールには SELECT + Cortex 呼び出し権限のみ |
| 認証 | PAT を使用。コード内にハードコードしない |

---

## 📁 ファイル構成

```
Financial_Planning/
├── README.md                    # 本ファイル
├── setup.sql                    # 環境構築 SQL（テーブル〜Agent 一気通貫）
├── streamlit_app.py             # Streamlit in Snowflake チャットUI
├── environment.yml              # Streamlit 依存パッケージ
└── generate_sample_pdfs.py      # サンプルPDF生成スクリプト
```

---

## ⚠️ 免責事項

- このデモは Snowflake Intelligence の機能紹介を目的としています
- SnowBank Trust は架空の金融機関です
- 表示されるデータはすべてサンプルデータです
- 実際の業務判断には使用しないでください

---

## 📚 参考リンク

- [Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-intelligence)
- [Cortex Agent](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
