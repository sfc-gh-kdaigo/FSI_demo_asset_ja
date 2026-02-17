# SnowCredit - クレジットカード業界向け Snowflake Intelligence デモ

架空のクレジットカード会社「SnowCredit」を題材にした Snowflake Cortex AI デモ環境

---

このアセットは、**Snowflake Cortex AI** の主要機能を活用し、クレジットカード会社の業務担当者向け AI アシスタントを構築するためのデモ環境です。

## 主な目的

自然言語でデータ分析・情報検索が可能な AI アシスタントを構築し、その仕組みを理解します。

**具体シナリオ**
- **顧客情報**（カード種別、年収、与信枠など）を自然言語で分析
- **取引データ**（利用金額、加盟店、ポイントなど）の傾向分析
- **業務ドキュメント**（マニュアル、FAQ、規約など）の検索
- 構造化データと非構造化データを組み合わせた複合分析

## このデモで学ぶこと

- Snowflake Cortex AI の全体像と主要な機能（Cortex Agent、Analyst、Search、Intelligence）
- Cortex Agent による複数ツール（Analyst / Search）のオーケストレーション
- **Semantic View** の具体的な実装手順（日本語対応）
- **Cortex Search Service** による RAG 検索の実装

---

## 利用データ（テーブル構成）

### 対象テーブル一覧

| テーブル名 | 件数 | 用途 |
|:---|:---|:---|
| **DIM_CUSTOMER** | 100件 | 顧客マスタ（人口統計情報、カード種別、与信枠など） |
| **DIM_MERCHANT** | 10件 | 加盟店マスタ（店舗名、業種、所在地など） |
| **DIM_CAMPAIGN** | 5件 | キャンペーンマスタ（ポイント還元率、期間など） |
| **FACT_TRANSACTION** | 500件 | 取引ファクト（利用金額、ポイント、海外利用フラグなど） |
| **OPERATION_DOCUMENT** | 18件 | 運用ドキュメント（マニュアル、FAQ、規約など） |

### テーブル間のリレーション

```
DIM_CUSTOMER ──┐
               │ CUSTOMER_KEY
               ▼
        FACT_TRANSACTION
               │ MERCHANT_KEY
               ▼
DIM_MERCHANT ──┘
```

### 主要カラム説明

#### DIM_CUSTOMER（顧客マスタ）
| カラム名 | 説明 |
|:---|:---|
| CUSTOMER_NAME | 顧客氏名 |
| CARD_TYPE | カード種別（一般/ゴールド/プラチナ） |
| ANNUAL_INCOME | 年収（円） |
| CREDIT_LIMIT | 利用限度額（円） |
| GENDER | 性別 |
| ADDRESS | 住所（都道府県） |
| OCCUPATION | 職業 |

#### FACT_TRANSACTION（取引ファクト）
| カラム名 | 説明 |
|:---|:---|
| TRANSACTION_AMOUNT | 取引金額（円） |
| TRANSACTION_DATETIME | 取引日時 |
| TRANSACTION_TYPE | 取引種別（売上/返品/取消） |
| EARNED_POINTS | 獲得ポイント |
| OVERSEAS_FLAG | 海外利用フラグ |

#### OPERATION_DOCUMENT（運用ドキュメント）
| カラム名 | 説明 |
|:---|:---|
| TITLE | ドキュメントタイトル |
| CONTENT | ドキュメント内容 |
| DOCUMENT_TYPE | 種別（マニュアル/FAQ/規約など） |
| DEPARTMENT | 担当部門 |

---

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                  Snowflake Intelligence                     │
│                    （チャットUI）                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Cortex Agent                           │
│             CREDIT_CARD_AGENT (claude-4-sonnet)             │
│  ┌─────────────────────────┬─────────────────────────────┐  │
│  │        Analyst          │       DocumentSearch        │  │
│  │   (構造化データ分析)     │    (ドキュメント検索)        │  │
│  └─────────────────────────┴─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│     Semantic View       │   │   Cortex Search Service     │
│  SV_CUSTOMER_TRANSACTION│   │  OPERATION_DOCUMENTS_CSS    │
│  (顧客・取引・加盟店)    │   │  (業務マニュアル・FAQ等)     │
└─────────────────────────┘   └─────────────────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│      DATA スキーマ       │   │       DATA スキーマ          │
│  DIM_CUSTOMER           │   │   OPERATION_DOCUMENT        │
│  DIM_MERCHANT           │   │                             │
│  FACT_TRANSACTION       │   │                             │
└─────────────────────────┘   └─────────────────────────────┘
```

### コンポーネント詳細

| コンポーネント | 役割 |
|:---|:---|
| **Snowflake Intelligence** | Cortex Agent を利用するためのチャット UI |
| **Cortex Agent** | ユーザーの質問を解析し、適切なツールを自動選択・実行 |
| **Analyst（ツール）** | Semantic View を通じて構造化データに対して自然言語から SQL を生成・実行 |
| **DocumentSearch（ツール）** | 業務ドキュメントに対する RAG 検索を提供 |

---

## Snowflake Intelligence への質問例

### 構造化データ分析（Analyst）
- 「カード種別ごとに顧客数と平均年収を教えてください」
- 「業種別の取引金額と取引件数を集計してください」
- 「取引金額が多い上位10名の顧客を教えて」
- 「月別の取引金額と取引件数の推移を見せて」

### 非構造化データ検索（DocumentSearch）
- 「カード紛失時の対応手順を教えてください」
- 「海外利用時の注意事項は何ですか」
- 「ポイントプログラムの規約について教えて」
- 「与信枠の増枠審査基準を確認したい」

### 複合分析（Analyst + DocumentSearch）
- 「最近高額取引をしている顧客を確認し、利用限度額の変更手続きについても教えてください」

---

## データベース構成

```
SNOW_CREDIT
├── DATA/           -- ビジネスデータ（テーブル）
│   ├── DIM_CUSTOMER
│   ├── DIM_MERCHANT
│   ├── DIM_CAMPAIGN
│   ├── FACT_TRANSACTION
│   └── OPERATION_DOCUMENT
│
└── AI/             -- AI コンポーネント
    ├── SV_CUSTOMER_TRANSACTION (Semantic View)
    ├── OPERATION_DOCUMENTS_CSS (Cortex Search Service)
    └── CREDIT_CARD_AGENT (Cortex Agent)
```

---

## セットアップ手順

### 前提条件
- Snowflake アカウント（ACCOUNTADMIN ロール）
- Cortex AI が利用可能なリージョン

### 実行手順

1. **Snowsight で SQL ワークシートを開く**

2. **`snowcredit_setup.sql` の内容を実行**
   - ロール・ウェアハウスの設定
   - データベース・スキーマの作成
   - テーブル作成・サンプルデータ投入
   - Semantic View の作成
   - Cortex Search Service の作成
   - Cortex Agent の作成

3. **Snowflake Intelligence でエージェントを選択**
   - Snowsight 左メニューから「Snowflake Intelligence」を開く
   - 「Credit Card Agent」を選択してチャット開始

---

## ファイル構成

| ファイル名 | 内容 |
|:---|:---|
| `snowcredit_setup.sql` | 環境構築スクリプト（全9セクション） |
| `README_SNOWCREDIT.md` | 本ドキュメント |

### snowcredit_setup.sql のセクション構成

| セクション | 内容 |
|:---|:---|
| 1. ロール・ウェアハウス設定 | ACCOUNTADMIN、SNOW_CREDIT_WH 作成 |
| 2. データベース・スキーマ作成 | SNOW_CREDIT.DATA、SNOW_CREDIT.AI |
| 3. テーブル作成（DDL） | 5テーブルの定義 |
| 4. サンプルデータ投入 | 日本語サンプルデータ |
| 5. Semantic View 作成 | SV_CUSTOMER_TRANSACTION（Verified Query 付き） |
| 6. Cortex Search Service 作成 | OPERATION_DOCUMENTS_CSS |
| 7. Cortex Agent 作成 | CREDIT_CARD_AGENT |
| 8. 検証 | データ件数・オブジェクト確認 |
| 9. 権限付与 | 他ロールへの権限付与（コメントアウト） |

---

## 環境設定

| 項目 | 値 |
|:---|:---|
| **DATABASE** | `SNOW_CREDIT` |
| **SCHEMA（データ）** | `DATA` |
| **SCHEMA（AI）** | `AI` |
| **WAREHOUSE** | `SNOW_CREDIT_WH` |
| **ROLE** | `ACCOUNTADMIN` |

---

## 備考

- 本アセットは**デモンストレーション目的**で作成されています
- サンプルデータは全て架空のデータであり、実際の顧客情報は含まれていません
- **SnowCredit** は架空のクレジットカード会社です
- Agent の回答には自動的に免責事項が付与されます
