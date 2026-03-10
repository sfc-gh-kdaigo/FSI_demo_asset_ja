"""
大手信託銀行 財務企画部 BPR デモ用 — サンプル PDF 生成スクリプト

使い方:
  pip install fpdf2
  python generate_sample_pdfs.py

出力:
  pdfs/regulation_expense_policy.pdf       — 経費精算規程
  pdfs/regulation_accounting_standards.pdf  — 会計処理基準通達
  pdfs/financial_report_2024q4.pdf         — 2024年度第4四半期決算資料
  pdfs/financial_report_2025q1.pdf         — 2025年度第1四半期決算資料

生成後、Snowflake の DOCUMENTS_STAGE にアップロードし、
setup.sql の Step 6 以降を実行してください。
"""

import os
from datetime import date
from fpdf import FPDF

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "pdfs")

_JP_FONT_PATH = None
_JP_FONT_BOLD_PATH = None


def _find_japanese_font():
    """システムにある日本語フォントを探す"""
    candidates = [
        "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/Library/Fonts/NotoSansJP-Regular.ttf",
        os.path.expanduser("~/Library/Fonts/NotoSansJP-Regular.ttf"),
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


def _find_japanese_bold_font():
    """太字フォント候補を探す（見つからなければ通常フォントにフォールバック）"""
    candidates = [
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
        "/Library/Fonts/NotoSansJP-Bold.ttf",
        os.path.expanduser("~/Library/Fonts/NotoSansJP-Bold.ttf"),
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


LIGHT_GRAY = (240, 240, 240)
MEDIUM_GRAY = (200, 200, 200)
DARK_GRAY = (80, 80, 80)
HEADER_BG = (0, 51, 102)
HEADER_FG = (255, 255, 255)
ACCENT_BLUE = (0, 102, 179)


class BusinessPDF(FPDF):
    """ビジネスドキュメント品質の日本語 PDF 生成クラス"""

    def __init__(self, doc_title="", doc_category="社内限", doc_id=""):
        super().__init__()
        self._doc_title = doc_title
        self._doc_category = doc_category
        self._doc_id = doc_id
        self._setup_fonts()
        self.set_auto_page_break(auto=True, margin=25)
        self.set_margins(20, 25, 20)

    def _setup_fonts(self):
        global _JP_FONT_PATH, _JP_FONT_BOLD_PATH
        if _JP_FONT_PATH is None:
            _JP_FONT_PATH = _find_japanese_font() or ""
        if _JP_FONT_BOLD_PATH is None:
            _JP_FONT_BOLD_PATH = _find_japanese_bold_font() or ""
        if _JP_FONT_PATH:
            self.add_font("JP", "", _JP_FONT_PATH)
        if _JP_FONT_BOLD_PATH:
            self.add_font("JPB", "", _JP_FONT_BOLD_PATH)

    def _jp(self, size=10):
        if _JP_FONT_PATH:
            self.set_font("JP", size=size)
        else:
            self.set_font("Helvetica", size=size)

    def _jp_bold(self, size=10):
        if _JP_FONT_BOLD_PATH:
            self.set_font("JPB", size=size)
        elif _JP_FONT_PATH:
            self.set_font("JP", size=size)
        else:
            self.set_font("Helvetica", "B", size)

    # --- ページヘッダー / フッター ---

    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*HEADER_BG)
        self.rect(0, 0, 210, 12, "F")
        self._jp(7)
        self.set_text_color(*HEADER_FG)
        self.set_y(3)
        self.cell(0, 6, self._doc_title, align="C")

        if self._doc_category:
            self.set_xy(155, 3)
            self.set_draw_color(255, 100, 100)
            self.set_fill_color(255, 230, 230)
            self._jp(6)
            self.set_text_color(180, 0, 0)
            cat_w = self.get_string_width(self._doc_category) + 6
            self.cell(cat_w, 5, self._doc_category, border=1, fill=True, align="C")

        self.set_text_color(0, 0, 0)
        self.set_draw_color(0, 0, 0)
        self.set_y(15)

    def footer(self):
        self.set_y(-15)
        self.set_draw_color(*MEDIUM_GRAY)
        self.line(20, self.get_y(), 190, self.get_y())
        self._jp(7)
        self.set_text_color(*DARK_GRAY)
        if self._doc_id:
            self.cell(0, 8, f"{self._doc_id}", align="L")
        self.cell(0, 8, f"- {self.page_no()} -", align="R")
        self.set_text_color(0, 0, 0)

    # --- タイトルページ ---

    def add_title_page(self, title, subtitle="", dept="財務企画部",
                       issued_date=None, version="1.0"):
        self.add_page()
        self.ln(40)

        self.set_draw_color(*ACCENT_BLUE)
        self.set_line_width(0.8)
        self.line(20, self.get_y(), 190, self.get_y())
        self.ln(8)

        self._jp_bold(24)
        self.set_text_color(*HEADER_BG)
        self.multi_cell(0, 14, title, align="C")
        self.ln(4)

        if subtitle:
            self._jp(14)
            self.set_text_color(*ACCENT_BLUE)
            self.multi_cell(0, 10, subtitle, align="C")
            self.ln(4)

        self.set_text_color(0, 0, 0)
        self.set_draw_color(*ACCENT_BLUE)
        self.line(20, self.get_y(), 190, self.get_y())
        self.ln(20)

        meta = [
            ("発行部門", dept),
            ("発行日", (issued_date or date.today()).strftime("%Y年%m月%d日")),
            ("版数", f"Ver. {version}"),
        ]
        if self._doc_category:
            meta.append(("取扱区分", self._doc_category))

        col_x = 60
        for label, value in meta:
            self._jp(11)
            self.set_x(col_x)
            self.set_text_color(*DARK_GRAY)
            self.cell(30, 8, f"{label}:", align="R")
            self.set_text_color(0, 0, 0)
            self._jp_bold(11)
            self.cell(60, 8, f"  {value}", align="L")
            self.ln(10)

    # --- セクション見出し ---

    def add_heading(self, text, level=1):
        self.ln(3)
        if level == 1:
            self.set_fill_color(*HEADER_BG)
            self._jp_bold(13)
            self.set_text_color(*HEADER_FG)
            self.cell(0, 10, f"  {text}", fill=True,
                      new_x="LMARGIN", new_y="NEXT")
            self.set_text_color(0, 0, 0)
            self.ln(4)
        elif level == 2:
            self.set_draw_color(*ACCENT_BLUE)
            self.set_line_width(0.4)
            self._jp_bold(11)
            self.set_text_color(*HEADER_BG)
            y = self.get_y()
            self.cell(0, 8, f"  {text}", new_x="LMARGIN", new_y="NEXT")
            self.line(20, self.get_y(), 190, self.get_y())
            self.set_text_color(0, 0, 0)
            self.ln(3)
        else:
            self._jp_bold(10)
            self.cell(0, 7, text, new_x="LMARGIN", new_y="NEXT")
            self.ln(2)

    # --- テキストブロック ---

    def add_text(self, text):
        self._jp(9.5)
        self.set_text_color(*DARK_GRAY)
        self.multi_cell(0, 5.5, text)
        self.set_text_color(0, 0, 0)
        self.ln(3)

    # --- テーブル ---

    def add_table(self, headers, rows, col_widths=None):
        """ヘッダー付きテーブルを描画する"""
        available_w = 170
        n = len(headers)
        if col_widths is None:
            col_widths = [available_w / n] * n

        self.set_fill_color(*HEADER_BG)
        self.set_text_color(*HEADER_FG)
        self.set_draw_color(*MEDIUM_GRAY)
        self._jp_bold(8.5)

        for i, h in enumerate(headers):
            self.cell(col_widths[i], 8, f" {h}", border=1, fill=True, align="C")
        self.ln()

        self.set_text_color(0, 0, 0)
        self._jp(8.5)
        fill = False
        for row in rows:
            if fill:
                self.set_fill_color(*LIGHT_GRAY)
            else:
                self.set_fill_color(255, 255, 255)
            for i, val in enumerate(row):
                align = "R" if _is_numeric(val) else "L"
                self.cell(col_widths[i], 7, f" {val} ", border=1, fill=True, align=align)
            self.ln()
            fill = not fill
        self.ln(4)

    # --- 箇条書き ---

    def add_bullet_list(self, items, indent=25):
        self._jp(9.5)
        self.set_text_color(*DARK_GRAY)
        for item in items:
            x = self.get_x()
            self.set_x(indent)
            self.cell(5, 5.5, "•")
            self.multi_cell(0, 5.5, f" {item}")
            self.ln(1)
        self.set_text_color(0, 0, 0)
        self.ln(2)

    # --- 区切り線 ---

    def add_separator(self):
        self.set_draw_color(*MEDIUM_GRAY)
        self.set_line_width(0.3)
        y = self.get_y()
        self.line(20, y, 190, y)
        self.ln(4)


def _is_numeric(val):
    s = str(val).replace(",", "").replace("%", "").replace("pt", "").strip()
    try:
        float(s)
        return True
    except ValueError:
        return s.startswith("+") or s.startswith("-") or s.startswith("△")


# ================================================================
# PDF 1: 経費精算規程
# ================================================================

def generate_expense_policy():
    pdf = BusinessPDF(
        doc_title="経費精算規程",
        doc_category="社内限",
        doc_id="REG-FIN-2024-001",
    )
    pdf.add_title_page(
        title="経費精算規程",
        subtitle="Financial Planning Division — Expense Policy",
        dept="財務企画部",
        issued_date=date(2024, 4, 1),
        version="3.2",
    )

    # --- 第1章 ---
    pdf.add_page()
    pdf.add_heading("第1章　総則")

    pdf.add_heading("第1条（目的）", level=2)
    pdf.add_text(
        "本規程は、当行の役職員が業務遂行上支出する経費の精算手続きについて定めるものである。"
        "適正かつ効率的な経費管理を実現し、内部統制の有効性を確保することを目的とする。"
    )

    pdf.add_heading("第2条（適用範囲）", level=2)
    pdf.add_text(
        "本規程は、当行の全役職員（出向者を含む）に適用する。派遣社員については別途定める派遣社員経費取扱要領に従う。"
    )

    pdf.add_heading("第3条（経費の定義）", level=2)
    pdf.add_text(
        "経費とは、業務遂行に必要な旅費交通費、交際費、会議費、通信費、消耗品費その他の費用をいう。"
        "以下に経費区分の一覧を示す。"
    )
    pdf.add_table(
        headers=["勘定科目コード", "勘定科目名", "主な内容", "承認レベル"],
        rows=[
            ["5023", "旅費交通費", "出張旅費、通勤費外の交通費", "課長"],
            ["5024", "交際費", "接待飲食費、贈答品", "部長"],
            ["5025", "会議費", "会議時の飲食費、会場費", "課長"],
            ["5026", "通信費", "電話代、郵送料、宅配便", "課長"],
            ["5027", "消耗品費", "事務用品、少額備品（10万円未満）", "課長"],
            ["5028", "研修費", "セミナー参加費、書籍購入", "部長"],
        ],
        col_widths=[30, 28, 72, 40],
    )

    # --- 第2章 ---
    pdf.add_heading("第2章　旅費交通費")

    pdf.add_heading("第4条（交通機関の利用基準）", level=2)
    pdf.add_bullet_list([
        "鉄道利用は原則として普通車とする。",
        "グリーン車の利用は、片道の乗車時間が2時間以上の場合、または部長職以上の役職者に限り認める。",
        "タクシーの利用は、公共交通機関の運行時間外、または重量物の運搬を伴う場合に限り認める。",
        "航空機は原則エコノミークラスとし、ビジネスクラスは飛行時間8時間以上かつ部長職以上に限る。",
    ])

    pdf.add_heading("第5条（出張日当・宿泊費上限）", level=2)
    pdf.add_text("国内出張の日当および宿泊費上限は、役職に応じて以下の通りとする。")
    pdf.add_table(
        headers=["役職", "日当（円/日）", "宿泊費上限（東京23区）", "宿泊費上限（その他）"],
        rows=[
            ["部長職以上", "3,000", "15,000", "12,000"],
            ["課長職", "2,500", "13,000", "10,000"],
            ["一般職", "2,000", "11,000", "9,000"],
        ],
        col_widths=[35, 35, 50, 50],
    )

    pdf.add_heading("第6条（海外出張）", level=2)
    pdf.add_text("海外出張の日当は地域区分に応じて定める。")
    pdf.add_table(
        headers=["地域区分", "日当（USD相当）", "宿泊費上限（USD相当）"],
        rows=[
            ["北米・欧州", "80", "250"],
            ["アジア（先進国）", "70", "200"],
            ["アジア（新興国）", "50", "150"],
            ["その他", "60", "180"],
        ],
        col_widths=[50, 60, 60],
    )

    # --- 第3章 ---
    pdf.add_heading("第3章　交際費・会議費")

    pdf.add_heading("第7条（交際費の上限）", level=2)
    pdf.add_table(
        headers=["役職", "1回上限（円）", "月間上限（円）", "備考"],
        rows=[
            ["部長職以上", "50,000", "200,000", "—"],
            ["課長職", "30,000", "100,000", "—"],
            ["一般職", "—", "—", "事前承認が必要"],
        ],
        col_widths=[35, 35, 35, 65],
    )
    pdf.add_text(
        "交際費の支出には、相手先の所属・役職・人数を記録すること。"
        "飲食を伴わない交際費（贈答品等）については、1件あたり10,000円を上限とする。"
    )

    pdf.add_heading("第8条（会議費）", level=2)
    pdf.add_table(
        headers=["区分", "1人あたり上限（円）", "承認者"],
        rows=[
            ["社内会議", "1,500", "課長"],
            ["社外会議（通常）", "5,000", "課長"],
            ["社外会議（役員同席）", "10,000", "部長"],
        ],
        col_widths=[50, 60, 60],
    )

    # --- 第4章 ---
    pdf.add_heading("第4章　精算手続き")

    pdf.add_heading("第9条（精算期限）", level=2)
    pdf.add_text(
        "経費の精算は、支出日から1ヶ月以内に行うこと。月末締めの場合は翌月10日までに提出する。"
        "期限を超過した場合は、所属長の理由書を添えて経理部に申請すること。"
    )

    pdf.add_heading("第10条（証憑の添付）", level=2)
    pdf.add_bullet_list([
        "経費精算には原則として領収書の原本を添付すること。",
        "領収書を紛失した場合は、所属長の承認を得た上で「領収書紛失届」を提出すること。",
        "クレジットカード利用の場合は、利用明細書をもって領収書に代えることができる。",
        "電子領収書（PDF）は、電子帳簿保存法の要件を満たす場合に限り原本として認める。",
    ])

    pdf.add_heading("第11条（承認フロー）", level=2)
    pdf.add_text("経費精算の承認フローは金額に応じて以下の通りとする。")
    pdf.add_table(
        headers=["金額区分", "承認者", "追加承認"],
        rows=[
            ["10万円未満", "課長", "—"],
            ["10万円以上50万円未満", "部長", "—"],
            ["50万円以上100万円未満", "部長", "経理部長"],
            ["100万円以上", "部長", "経理部長 + 担当役員"],
        ],
        col_widths=[50, 50, 70],
    )

    path = os.path.join(OUTPUT_DIR, "regulation_expense_policy.pdf")
    pdf.output(path)
    print(f"  生成: {path}")


# ================================================================
# PDF 2: 会計処理基準通達
# ================================================================

def generate_accounting_standards():
    pdf = BusinessPDF(
        doc_title="会計処理基準通達",
        doc_category="社内限",
        doc_id="REG-ACC-2024-003",
    )
    pdf.add_title_page(
        title="会計処理基準通達",
        subtitle="Accounting Standards & Procedures Circular",
        dept="経理部 / 財務企画部",
        issued_date=date(2024, 4, 1),
        version="5.1",
    )

    # --- 1. 収益認識 ---
    pdf.add_page()
    pdf.add_heading("1. 収益認識基準")

    pdf.add_heading("1.1 貸出金利息", level=2)
    pdf.add_text(
        "貸出金利息は、利息計算期間に基づき発生主義で計上する。"
        "期末日における経過利息は未収収益として計上すること。"
        "変動金利貸出については、金利見直し日を基準に利息を再計算する。"
    )

    pdf.add_heading("1.2 有価証券利息配当金", level=2)
    pdf.add_text(
        "利付債の利息は、利払日ベースで計上する。"
        "期末における経過利息は未収収益として処理する。"
        "株式配当金は、配当確定日（株主総会決議日）に計上する。"
    )

    pdf.add_heading("1.3 信託報酬", level=2)
    pdf.add_text(
        "信託報酬は、信託契約に基づく計算期間で按分計上する。"
        "成功報酬型の場合は、確定時点で収益計上する。"
    )
    pdf.add_table(
        headers=["信託報酬種別", "計上基準", "計算期間", "備考"],
        rows=[
            ["基本報酬", "按分計上", "信託計算期間", "月次按分"],
            ["成功報酬", "確定時計上", "評価基準日", "ベンチマーク超過分"],
            ["事務管理報酬", "按分計上", "四半期", "AUM比例"],
        ],
        col_widths=[35, 35, 35, 65],
    )

    pdf.add_heading("1.4 役務取引等収益", level=2)
    pdf.add_text("為替手数料、振込手数料等は、役務提供完了時に計上する。")

    # --- 2. 有価証券評価 ---
    pdf.add_heading("2. 有価証券の評価")

    pdf.add_table(
        headers=["保有区分", "評価方法", "評価差額の処理", "減損基準"],
        rows=[
            ["売買目的", "時価法", "当期損益", "—"],
            ["満期保有目的", "償却原価法（定額法）", "—", "—"],
            ["その他有価証券", "時価法", "純資産の部", "50%以上: 必須 / 30〜50%: 要検討"],
            ["子会社・関連会社株式", "原価法", "—", "実質価額50%以上下落"],
        ],
        col_widths=[35, 38, 38, 59],
    )

    pdf.add_heading("2.1 減損処理の判定フロー", level=2)
    pdf.add_text(
        "時価が取得原価に比べ50%以上下落した場合は減損処理を行う。"
        "30%以上50%未満の下落の場合は、回復可能性を検討の上、減損の要否を判断する。"
        "回復可能性の判定にあたっては、過去の株価推移、発行体の財務状況、業界動向等を総合的に勘案する。"
    )

    # --- 3. 決算補正仕訳 ---
    pdf.add_heading("3. 決算補正仕訳")

    pdf.add_heading("3.1 決算補正仕訳の分類", level=2)
    pdf.add_table(
        headers=["分類", "具体例", "計上頻度", "起票部門"],
        rows=[
            ["経過勘定", "未収収益・未払費用・前受収益・前払費用", "月次/四半期", "各事業部"],
            ["引当金繰入", "貸倒引当金・賞与引当金・退職給付引当金", "四半期/年次", "経理部"],
            ["減価償却", "有形固定資産・無形固定資産", "月次", "経理部"],
            ["有価証券評価", "評価損益・減損損失", "四半期", "市場部門"],
            ["税効果", "繰延税金資産・負債", "四半期", "経理部"],
        ],
        col_widths=[28, 68, 30, 44],
    )

    pdf.add_heading("3.2 決算補正仕訳の承認フロー", level=2)
    pdf.add_text(
        "決算補正仕訳は、起票者 → 課長承認 → 部長承認の3段階で処理する。"
        "金額が10百万円以上の場合は、経理部長の追加承認を要する。"
    )
    pdf.add_table(
        headers=["金額区分", "承認ステップ", "最終承認者"],
        rows=[
            ["10百万円未満", "起票者 → 課長 → 部長", "部長"],
            ["10百万円以上100百万円未満", "起票者 → 課長 → 部長 → 経理部長", "経理部長"],
            ["100百万円以上", "起票者 → 課長 → 部長 → 経理部長 → CFO", "CFO"],
        ],
        col_widths=[45, 80, 45],
    )

    # --- 4. 管理会計との調整 ---
    pdf.add_heading("4. 管理会計との調整")

    pdf.add_heading("4.1 財管差の定義と分類", level=2)
    pdf.add_text(
        "財管差とは、財務会計上の金額と管理会計上の金額の差額をいう。"
        "原因別に以下の3類型に分類して管理する。"
    )
    pdf.add_table(
        headers=["財管差類型", "定義", "主な発生要因", "調整頻度"],
        rows=[
            ["配賦差", "本部費・共通費の配賦基準の違い", "ABC原価計算 vs 一律配賦", "四半期"],
            ["計上時期差", "収益費用の認識タイミングの違い", "月次按分 vs 実現主義", "月次"],
            ["計上範囲差", "管理会計固有の社内仕切り等", "TP、資本コスト賦課", "月次"],
        ],
        col_widths=[28, 50, 52, 40],
    )

    pdf.add_heading("4.2 社内仕切り（TP）の処理", level=2)
    pdf.add_table(
        headers=["仕切り種別", "計算基準", "計算頻度", "配賦先"],
        rows=[
            ["金利仕切り", "ALM基準レート", "月次", "各事業部"],
            ["為替仕切り", "実勢レート", "取引発生時", "市場部門"],
            ["手数料仕切り", "サービス提供実績", "四半期", "対象部門"],
        ],
        col_widths=[35, 45, 35, 55],
    )

    path = os.path.join(OUTPUT_DIR, "regulation_accounting_standards.pdf")
    pdf.output(path)
    print(f"  生成: {path}")


# ================================================================
# PDF 3/4: 決算概要レポート
# ================================================================

def generate_financial_report(fiscal_year, quarter, period_label):
    pdf = BusinessPDF(
        doc_title=f"{fiscal_year}年度 {period_label} 決算概要",
        doc_category="社内限（役員限り）",
        doc_id=f"RPT-FIN-{fiscal_year}-{quarter.upper()}",
    )
    pdf.add_title_page(
        title=f"{fiscal_year}年度 {period_label}\n決算概要報告書",
        subtitle="Quarterly Financial Results Summary",
        dept="財務企画部",
        issued_date=date(fiscal_year, 9, 30) if "q2" in quarter or "q4" in quarter
                     else date(fiscal_year, 6, 30),
        version="1.0",
    )

    # --- 1. 業績概要 ---
    pdf.add_page()
    pdf.add_heading("1. 業績ハイライト")

    pdf.add_table(
        headers=["項目", "当期実績（億円）", "前年同期（億円）", "増減率"],
        rows=[
            ["経常収益", "4,520", "4,296", "+5.2%"],
            ["  資金運用収益", "2,810", "2,615", "+7.5%"],
            ["  信託報酬", "890", "823", "+8.1%"],
            ["  役務取引等収益", "680", "645", "+5.4%"],
            ["経常費用", "3,650", "3,520", "+3.7%"],
            ["  営業経費", "2,180", "2,106", "+3.5%"],
            ["経常利益", "870", "807", "+7.8%"],
            ["当期純利益", "620", "568", "+9.2%"],
        ],
        col_widths=[50, 40, 40, 40],
    )

    pdf.add_heading("主要経営指標", level=2)
    pdf.add_table(
        headers=["指標", "当期", "前期末", "増減"],
        rows=[
            ["OHR（経費率）", "48.2%", "49.0%", "△0.8pt"],
            ["ROE", "7.8%", "7.2%", "+0.6pt"],
            ["自己資本比率（国内基準）", "10.8%", "10.5%", "+0.3pt"],
            ["不良債権比率", "0.42%", "0.47%", "△0.05pt"],
            ["LCR（流動性カバレッジ比率）", "142.5%", "138.2%", "+4.3pt"],
        ],
        col_widths=[55, 35, 35, 45],
    )

    # --- 2. セグメント別 ---
    pdf.add_heading("2. セグメント別業績")

    pdf.add_table(
        headers=["セグメント", "経常収益（億円）", "経常利益（億円）", "前年同期比"],
        rows=[
            ["リテール事業", "1,250", "180", "+3.8%"],
            ["法人事業", "1,080", "210", "+6.5%"],
            ["市場事業", "920", "290", "+12.3%"],
            ["信託事業", "890", "150", "+8.1%"],
            ["不動産事業", "380", "40", "+2.1%"],
            ["合計", "4,520", "870", "+7.8%"],
        ],
        col_widths=[40, 45, 45, 40],
    )

    pdf.add_heading("セグメント別コメント", level=2)

    pdf.add_heading("リテール事業", level=3)
    pdf.add_text(
        "住宅ローン残高は微増。資産運用関連手数料が増加し、経常収益は前年同期比+3.8%。"
        "顧客基盤の拡大に向けたデジタル投資を継続中。非対面チャネル経由の投信販売比率が30%を突破。"
    )

    pdf.add_heading("市場事業", level=3)
    pdf.add_text(
        "金利上昇局面を捉えた運用が奏功し、資金運用収益は前年同期比+12.3%と大幅増。"
        "一方、外国債券ポートフォリオの評価損が一部発生（△15億円）。"
        "ALM運営の高度化により、金利リスク量は許容範囲内で管理。"
    )

    pdf.add_heading("信託事業", level=3)
    pdf.add_text(
        "年金信託の受託残高が増加し、信託報酬は前年同期比+8.1%と好調。"
        "企業型DC（確定拠出年金）の新規受託が堅調に推移。"
    )

    # --- 3. 財務健全性 ---
    pdf.add_heading("3. 財務健全性・リスク管理")

    pdf.add_table(
        headers=["リスク指標", "基準値", "当期実績", "判定"],
        rows=[
            ["自己資本比率", "8.0%以上", "10.8%", "○"],
            ["Tier1比率", "6.0%以上", "9.2%", "○"],
            ["不良債権比率", "1.0%以下", "0.42%", "○"],
            ["LCR", "100%以上", "142.5%", "○"],
            ["大口与信集中度", "25%以下", "12.3%", "○"],
        ],
        col_widths=[50, 35, 35, 50],
    )

    pdf.add_text(
        "信用コストは引き続き低位で推移。与信ポートフォリオの分散化を推進中。"
        "政策保有株式の縮減を計画的に実施し、当期は△80億円（簿価）を売却。"
    )

    # --- 4. 通期見通し ---
    pdf.add_heading("4. 通期見通し")

    pdf.add_table(
        headers=["項目", "通期計画（億円）", "上期実績（億円）", "進捗率"],
        rows=[
            ["経常利益", "1,680", "870", "51.8%"],
            ["当期純利益", "1,150", "620", "53.9%"],
            ["配当（1株当たり）", "120円", "60円（中間）", "50.0%"],
        ],
        col_widths=[45, 45, 45, 35],
    )

    pdf.add_text(f"{fiscal_year}年度通期の業績予想は据え置き。おおむね計画通りの進捗。")

    pdf.add_heading("下期リスク要因", level=2)
    pdf.add_bullet_list([
        "海外金利動向（米国利下げペースの不確実性）",
        "為替変動リスク（円高進行時の外貨建資産評価損）",
        "国内景気の減速リスク（個人消費の鈍化）",
        "地政学リスク（中東情勢の緊迫化による原油価格変動）",
        "規制環境の変化（バーゼルIII最終化の影響）",
    ])

    filename = f"financial_report_{fiscal_year}{quarter}.pdf"
    path = os.path.join(OUTPUT_DIR, filename)
    pdf.output(path)
    print(f"  生成: {path}")


# ================================================================
# メイン
# ================================================================

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("サンプル PDF を生成中...\n")

    generate_expense_policy()
    generate_accounting_standards()
    generate_financial_report(2024, "q4", "第4四半期")
    generate_financial_report(2025, "q1", "第1四半期")

    print(f"\n完了: {OUTPUT_DIR}/ に 4 ファイルを生成しました。")
    print("次のステップ: Snowflake の DOCUMENTS_STAGE にアップロードし、")
    print("setup.sql の Step 6 以降を実行してください。")


if __name__ == "__main__":
    main()
