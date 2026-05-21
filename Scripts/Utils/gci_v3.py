import pandas as pd
import numpy as np

# -----------------------------
# USER SETTINGS
# -----------------------------
file_path = "/home/proparm/OneDrive/Year 4/MIE498/Data/sims/spalart_allmaras/gci_script_inputs.xlsx"

USE_2GRID_FALLBACK = False 
p_assumed = 2.0

ASYMPTOTIC_TOL = 0.05
MIN_VALID_P = 0.1

# -----------------------------
# LOAD FILE
# -----------------------------
raw = pd.read_excel(file_path, header=None)

# -----------------------------
# EXTRACT MESH INFO
# -----------------------------
mesh_info = raw.iloc[1:4, 0:4]
mesh_info.columns = ["Mesh", "TotalVolume", "NumCells", "h"]

N1 = mesh_info.iloc[0]["NumCells"]
N2 = mesh_info.iloc[1]["NumCells"]
N3 = mesh_info.iloc[2]["NumCells"]

h1 = mesh_info.iloc[0]["h"]
h2 = mesh_info.iloc[1]["h"]
h3 = mesh_info.iloc[2]["h"]

r21 = h2 / h1
r32 = h3 / h2

# -----------------------------
# EXTRACT DATA
# -----------------------------
def extract_block(start_row):
    block = raw.iloc[start_row:start_row+4, :]
    block = block.dropna(how="all")

    data = {}
    for i in range(1, len(block)):
        var = block.iloc[i, 0]
        val = block.iloc[i, -1]
        data[var] = val

    return data

coarse = extract_block(5)
medium = extract_block(10)
fine = extract_block(15)

variables = ["Cd", "Cl", "Cm"]

# -----------------------------
# FUNCTIONS
# -----------------------------
def compute_p(phi1, phi2, phi3, r21, r32):
    e32 = phi3 - phi2
    e21 = phi2 - phi1

    if abs(e21) < 1e-14 or abs(e32) < 1e-14:
        return np.nan

    s = np.sign(e32 / e21)
    p = np.log(abs(e32 / e21)) / np.log(r21)

    for _ in range(50):
        try:
            q = np.log((r21**p - s) / (r32**p - s))
            p_new = (np.log(abs(e32 / e21)) + q) / np.log(r21)
        except:
            return np.nan

        if abs(p_new - p) < 1e-8:
            break
        p = p_new

    return p

# -----------------------------
# BUILD TABLE
# -----------------------------
rows = []

for var in variables:

    phi1 = fine[var]
    phi2 = medium[var]
    phi3 = coarse[var]

    p = compute_p(phi1, phi2, phi3, r21, r32)

    use_3grid = True
    reason = "OK"

    try:
        phi_ext = (r21**p * phi1 - phi2) / (r21**p - 1)

        ea21 = abs((phi1 - phi2) / phi1)
        ea32 = abs((phi2 - phi3) / phi2)
        eext = abs((phi_ext - phi1) / phi_ext)

        GCI21 = 1.25 * ea21 / (r21**p - 1)
        GCI32 = 1.25 * ea32 / (r32**p - 1)

        asymp = GCI32 / (GCI21 * r21**p)

        if np.isnan(p) or p < MIN_VALID_P:
            use_3grid = False
            reason = "Invalid p"

        if not (1 - ASYMPTOTIC_TOL <= asymp <= 1 + ASYMPTOTIC_TOL):
            use_3grid = False
            reason = "Not asymptotic"

    except:
        use_3grid = False
        reason = "Error"

    # -----------------------------
    # 2-GRID FALLBACK
    # -----------------------------
    if not use_3grid and USE_2GRID_FALLBACK:

        ea21 = abs((phi1 - phi2) / phi1)

        phi_ext = (r21**p_assumed * phi1 - phi2) / (r21**p_assumed - 1)
        eext = abs((phi_ext - phi1) / phi_ext)

        GCI21 = 1.25 * ea21 / (r21**p_assumed - 1)

        GCI32 = np.nan
        asymp = np.nan

        method = "2-grid"
    else:
        method = "3-grid"

    er32 = phi3 - phi2
    er21 = phi2 - phi1

    # -----------------------------
    # ASME TABLE FORMAT
    # -----------------------------
    rows.append([var, "N", N1, N2, N3])
    rows.append([var, "phi", phi1, phi2, phi3])
    rows.append([var, "r21", r21, "", ""])
    rows.append([var, "r32", r32, "", ""])
    rows.append([var, "e32/e21' (%)", er32/er21, "", ""])
    rows.append([var, "p", p, "", ""])
    rows.append([var, "phi_ext", phi_ext, "", ""])
    rows.append([var, "e_a21 (%)", ea21 * 100, "", ""])
    rows.append([var, "e_a32 (%)", ea32 * 100, "", ""])
    rows.append([var, "e_ext (%)", eext * 100, "", ""])
    rows.append([var, "GCI21 (%)", GCI21 * 100, "", ""])
    rows.append([var, "GCI32 (%)", GCI32 * 100 if not np.isnan(GCI32) else "", "", ""])
    rows.append([var, "GCI ratio", asymp, "", ""])
    # rows.append([var, "Method", method, "", ""])
    # rows.append([var, "Reason", reason, "", ""])
    rows.append(["", "", "", "", ""])

# -----------------------------
# EXPORT
# -----------------------------
df = pd.DataFrame(rows, columns=["Variable", "Parameter", "Fine", "Medium", "Coarse"])
df.to_excel("gci_asme_table.xlsx", index=False)

print("Final ASME-style table with errors created")