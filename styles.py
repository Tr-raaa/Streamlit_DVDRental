"""
styles.py — Corporate design system shared across all pages.
Import: from styles import inject_css, page_header, metric_card
"""
import streamlit as st

# ── Color tokens ──────────────────────────────────────────────────────────────
NAVY   = "#08112a"
BLUE   = "#2563eb"
LBLUE  = "#dbeafe"
BG     = "#f0f4fb"
WHITE  = "#ffffff"
DGRAY  = "#64748b"
GREEN  = "#059669"
AMBER  = "#d97706"
RED    = "#dc2626"
PURPLE = "#7c3aed"


MASTER_CSS = """
<style>
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Serif+Display&display=swap');

html, body, [class*="css"] { font-family: 'DM Sans', sans-serif !important; }

/* ── Topbar matches background ── */
header[data-testid="stHeader"] {
    background: #f0f4fb !important;
    border-bottom: none !important;
    box-shadow: none !important;
}
.stDeployButton, [data-testid="stToolbar"], [data-testid="stDecoration"] { display:none !important; }

/* ── App background ── */
.stApp { background: #f0f4fb !important; }
.main .block-container { padding: 2rem 3rem 3rem !important; max-width: 1280px; }

/* ── Sidebar ── */
section[data-testid="stSidebar"] {
    background: linear-gradient(180deg, #07102a 0%, #0c1a3a 60%, #091426 100%) !important;
    border-right: 1px solid rgba(255,255,255,0.05) !important;
    min-width: 236px !important;
}
section[data-testid="stSidebar"] * { color: #b8ccee !important; }

/* Hide Streamlit's default page nav — we use custom links */
section[data-testid="stSidebar"] [data-testid="stSidebarNav"],
section[data-testid="stSidebar"] [data-testid="stSidebarNavItems"],
div[data-testid="stSidebarNavItems"],
nav[data-testid="stSidebarNav"] { display: none !important; }

/* Page link buttons */
section[data-testid="stSidebar"] a[data-testid="stPageLink-NavLink"] {
    border-radius: 8px !important; padding: .42rem .9rem !important;
    margin: .08rem 0 !important; font-size: .875rem !important;
    font-weight: 500 !important; color: #94afd4 !important;
    text-decoration: none !important; transition: background .15s !important;
}
section[data-testid="stSidebar"] a[data-testid="stPageLink-NavLink"]:hover {
    background: rgba(255,255,255,0.09) !important; color: white !important;
}
section[data-testid="stSidebar"] a[data-testid="stPageLink-NavLink"][aria-current="page"] {
    background: rgba(37,99,235,0.28) !important; color: #93c5fd !important; font-weight: 600 !important;
}

/* ── Metric cards ── */
[data-testid="stMetric"] {
    background: white !important; border: 1px solid #e2e8f4 !important;
    border-radius: 16px !important; padding: 1.3rem 1.5rem !important;
    box-shadow: 0 2px 10px rgba(8,17,42,0.06) !important;
}
[data-testid="stMetricLabel"] {
    font-size: .7rem !important; font-weight: 700 !important;
    letter-spacing: .1em !important; text-transform: uppercase !important; color: #7a8aaa !important;
}
[data-testid="stMetricValue"] { font-size: 1.8rem !important; font-weight: 700 !important; color: #08112a !important; }

/* ── Primary button ── */
.stButton > button, .stFormSubmitButton > button {
    background: linear-gradient(135deg, #1a3a6b 0%, #2563eb 100%) !important;
    color: white !important; border: none !important; border-radius: 10px !important;
    font-weight: 600 !important; letter-spacing: .02em !important;
    box-shadow: 0 4px 14px rgba(37,99,235,0.3) !important;
}
.stButton > button:hover { transform: translateY(-1px) !important; box-shadow: 0 6px 20px rgba(37,99,235,0.45) !important; }

/* ── Selectbox / inputs ── */
.stSelectbox > div > div, .stNumberInput input, .stTextInput input, .stTextArea textarea {
    border-radius: 10px !important; border: 1.5px solid #e2e8f4 !important;
    background: white !important; font-size: .9rem !important;
}

/* ── Tabs ── */
.stTabs [data-baseweb="tab-list"] {
    background: white !important; border-radius: 12px !important;
    border: 1px solid #e2e8f4 !important; padding: .3rem !important;
    gap: .2rem !important;
}
.stTabs [data-baseweb="tab"] {
    border-radius: 8px !important; font-weight: 500 !important;
    font-size: .88rem !important; color: #7a8aaa !important;
    padding: .5rem 1.1rem !important;
}
.stTabs [aria-selected="true"] {
    background: #2563eb !important; color: white !important;
    font-weight: 600 !important;
}

/* ── Dataframe ── */
.stDataFrame { border-radius: 12px !important; overflow: hidden !important; border: 1px solid #e2e8f4 !important; }

/* ── Expander ── */
.streamlit-expanderHeader {
    background: white !important; border: 1px solid #e2e8f4 !important;
    border-radius: 10px !important; font-weight: 600 !important;
}

/* ── Misc ── */
hr { border-color: #e2e8f4 !important; margin: 1.4rem 0 !important; }
footer { visibility: hidden !important; }
#MainMenu { visibility: hidden !important; }
h1 { font-family: 'DM Serif Display', serif !important; color: #08112a !important;
     font-size: 2rem !important; font-weight: 400 !important; letter-spacing: -.025em !important; }
h2 { font-size: 1.08rem !important; font-weight: 600 !important; color: #1e2a45 !important; }
h3 { color: #1e2a45 !important; font-weight: 600 !important; }
</style>
"""


def inject_css():
    st.markdown(MASTER_CSS, unsafe_allow_html=True)


def render_sidebar():
    """Consistent sidebar on every page."""
    st.markdown("""
    <div style="padding:1.75rem 1rem 1rem">
        <div style="font-size:1.3rem;font-weight:700;color:white;letter-spacing:-.02em">🎬 FilmAnalytics</div>
        <div style="font-size:.62rem;font-weight:700;letter-spacing:.14em;text-transform:uppercase;
                    color:#3a5a8a;margin-top:.25rem">Corporate Dashboard</div>
    </div>
    <div style="border-top:1px solid rgba(255,255,255,0.07);margin:0 1rem .4rem"></div>
    <div style="padding:.4rem 1rem .15rem;font-size:.6rem;font-weight:700;
                letter-spacing:.14em;text-transform:uppercase;color:#2d4f80">Analytics</div>
    """, unsafe_allow_html=True)
    st.page_link("pages/1_Genre_Performance.py",  label="Genre Performance",  icon="🎭")
    st.page_link("pages/2_Film_Rating_Impact.py", label="Film Rating Impact", icon="⭐")
    st.markdown("""
    <div style="padding:.5rem 1rem .15rem;font-size:.6rem;font-weight:700;
                letter-spacing:.14em;text-transform:uppercase;color:#2d4f80">Predictions</div>
    """, unsafe_allow_html=True)
    st.page_link("pages/3_Next_Big_Hit.py",        label="Next Big Hit",       icon="🚀")
    st.page_link("pages/4_Inventory_Forecast.py",  label="Inventory Forecast", icon="📦")
    st.markdown('<div style="border-top:1px solid rgba(255,255,255,0.07);margin:1rem 1rem .6rem"></div>', unsafe_allow_html=True)
    st.page_link("app.py", label="Home", icon="🏠")
    st.caption("Powered by Streamlit + PostgreSQL")


def page_header(icon: str, title: str, subtitle: str = ""):
    sub = f'<p style="color:#7a8aaa;font-size:.9rem;margin:.3rem 0 0">{subtitle}</p>' if subtitle else ""
    st.markdown(f"""
    <div style="margin-bottom:1.75rem;padding-bottom:1.4rem;border-bottom:2px solid #e2e8f4">
        <h1 style="margin:0">{icon}&nbsp; {title}</h1>
        {sub}
    </div>
    """, unsafe_allow_html=True)


def status_banner(ok: bool, msg_ok="", msg_err=""):
    if ok:
        st.markdown(f"""
        <div style="background:linear-gradient(135deg,#07102a,#1a3a6b);border-radius:14px;
                    padding:1.1rem 1.75rem;margin-bottom:1.5rem;color:white;font-size:.95rem;font-weight:500">
            ✅ &nbsp;{msg_ok}
        </div>""", unsafe_allow_html=True)
    else:
        st.markdown(f"""
        <div style="background:#fff5f5;border:1px solid #fed7d7;border-left:4px solid #dc2626;
                    border-radius:14px;padding:1.1rem 1.75rem;margin-bottom:1.5rem">
            <div style="font-weight:700;color:#c53030">⚠️ {msg_err}</div>
        </div>""", unsafe_allow_html=True)


def alert_box(level: str, title: str, body: str = ""):
    """level: 'error' | 'warning' | 'success' | 'info'"""
    cfg = {
        "error":   ("#fff5f5", "#fed7d7", "#dc2626", "#c53030"),
        "warning": ("#fffbeb", "#fde68a", "#d97706", "#92400e"),
        "success": ("#f0fdf4", "#bbf7d0", "#059669", "#065f46"),
        "info":    ("#eff6ff", "#bfdbfe", "#2563eb", "#1e40af"),
    }
    bg, bd, ac, tc = cfg.get(level, cfg["info"])
    body_html = f'<div style="color:{tc};font-size:.875rem;margin-top:.3rem">{body}</div>' if body else ""
    st.markdown(f"""
    <div style="background:{bg};border:1px solid {bd};border-left:4px solid {ac};
                border-radius:14px;padding:1rem 1.5rem;margin-bottom:.75rem">
        <div style="font-weight:700;color:{tc}">{title}</div>{body_html}
    </div>""", unsafe_allow_html=True)


def section_label(text: str, color: str = "#2563eb"):
    st.markdown(f"""
    <div style="font-size:.65rem;font-weight:700;letter-spacing:.12em;text-transform:uppercase;
                color:{color};margin-bottom:.6rem;margin-top:.2rem">{text}</div>
    """, unsafe_allow_html=True)
