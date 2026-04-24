import pandas as pd
from pathlib import Path

def analyze_sales(csv_path: str) -> dict:
    """Analyze sales data from a CSV file and return summary statistics."""
    df = pd.read_csv(csv_path)
    
    summary = {
        "total_revenue": df["amount"].sum(),
        "avg_order": df["amount"].mean(),
        "top_product": df.groupby("product")["amount"].sum().idxmax(),
        "total_orders": len(df),
        "date_range": f"{df['date'].min()} to {df['date'].max()}"
    }
    
    return summary

if __name__ == "__main__":
    result = analyze_sales("sales_2024.csv")
    for key, value in result.items():
        print(f"{key}: {value}")
