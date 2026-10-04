import pandas as pd

RAW_COLUMN_NAMES = [
    "checking_status", "duration_months", "credit_history", "purpose",
    "credit_amount", "savings_status", "employment_since", "installment_rate",
    "personal_status_sex", "other_debtors", "residence_since", "property",
    "age", "other_installment_plans", "housing", "existing_credits",
    "job", "num_dependents", "telephone", "foreign_worker", "target",
]

NUMERIC_COLUMNS = [
    "duration_months", "credit_amount", "installment_rate", "residence_since",
    "age", "existing_credits", "num_dependents",
]

# Code -> readable label lookups, taken from the dataset's german.names file.
CATEGORY_MAPS = {
    "checking_status": {"A11": "< 0 DM", "A12": "0 - 200 DM", "A13": ">= 200 DM",
                         "A14": "no checking account"},
    "credit_history": {"A30": "no credits / all paid duly",
                        "A31": "all credits at this bank paid duly",
                        "A32": "existing credits paid duly",
                        "A33": "delay in past",
                        "A34": "critical / other credits existing"},
    "purpose": {"A40": "car (new)", "A41": "car (used)", "A42": "furniture/equipment",
                "A43": "radio/tv", "A44": "domestic appliances", "A45": "repairs",
                "A46": "education", "A47": "vacation", "A48": "retraining",
                "A49": "business", "A410": "other"},
    "savings_status": {"A61": "< 100 DM", "A62": "100 - 500 DM", "A63": "500 - 1000 DM",
                        "A64": ">= 1000 DM", "A65": "unknown / no savings account"},
    "employment_since": {"A71": "unemployed", "A72": "< 1 year", "A73": "1 - 4 years",
                          "A74": "4 - 7 years", "A75": ">= 7 years"},
    "personal_status_sex": {"A91": "male: divorced/separated",
                             "A92": "female: divorced/separated/married",
                             "A93": "male: single", "A94": "male: married/widowed",
                             "A95": "female: single"},
    "other_debtors": {"A101": "none", "A102": "co-applicant", "A103": "guarantor"},
    "property": {"A121": "real estate", "A122": "building society/life insurance",
                 "A123": "car or other property", "A124": "unknown / none"},
    "other_installment_plans": {"A141": "bank", "A142": "stores", "A143": "none"},
    "housing": {"A151": "rent", "A152": "own", "A153": "for free"},
    "job": {"A171": "unemployed/unskilled non-resident", "A172": "unskilled resident",
            "A173": "skilled employee/official",
            "A174": "management/self-employed/highly qualified"},
    "telephone": {"A191": "none", "A192": "yes"},
    "foreign_worker": {"A201": "yes", "A202": "no"},
}


def load_raw_data(path: str) -> pd.DataFrame:
    """Load the raw, space/comma-separated german.data file with proper column names."""
    return pd.read_csv(path, header=None, names=RAW_COLUMN_NAMES)


def decode_categorical(df: pd.DataFrame) -> pd.DataFrame:
    """Map coded categorical values (e.g. 'A34') to readable labels."""
    df = df.copy()
    for column, mapping in CATEGORY_MAPS.items():
        df[column] = df[column].map(mapping)
    return df


def recode_target(df: pd.DataFrame) -> pd.DataFrame:
    """Convert the raw 1/2 target into a readable Good/Bad `risk` column."""
    df = df.copy()
    df["risk"] = df["target"].map({1: "Good", 2: "Bad"})
    return df.drop(columns=["target"])


def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add `age_group` (segmentation) and `credit_per_month` (repayment burden proxy)."""
    df = df.copy()
    bins = [18, 25, 35, 45, 55, 76]
    labels = ["19-25", "26-35", "36-45", "46-55", "56+"]
    df["age_group"] = pd.cut(df["age"], bins=bins, labels=labels, right=True)
    df["credit_per_month"] = (df["credit_amount"] / df["duration_months"]).round(2)
    return df


def clean_data(raw_path: str) -> pd.DataFrame:
    """Run the full cleaning pipeline: load -> decode -> recode target -> engineer features."""
    df = load_raw_data(raw_path)
    df = decode_categorical(df)
    df = recode_target(df)
    df = engineer_features(df)
    return df


if __name__ == "__main__":
    # Lets this script be run directly: `python src/preprocessing.py`
    # regenerates data/processed/german_credit_processed.csv from the raw file.
    cleaned = clean_data("data/raw/german.data")
    cleaned.to_csv("data/processed/german_credit_processed.csv", index=False)
    print(f"Saved cleaned dataset: {cleaned.shape[0]} rows, {cleaned.shape[1]} columns")
