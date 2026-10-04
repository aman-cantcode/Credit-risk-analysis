# Credit Risk Analysis & Prediction

An end-to-end credit risk analysis project using the UCI Statlog German Credit Dataset.

The project covers:

* Data cleaning and preprocessing
* Exploratory Data Analysis
* SQL-based analysis using MySQL
* Logistic Regression classification
* Model evaluation
* Business insights

## Dataset

The project uses the **Statlog (German Credit Data)** dataset from the UCI Machine Learning Repository.

The raw dataset is already included in:

```text
data/raw/german.data
```

## Setup

Create and activate a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

Install the required packages:

```bash
pip install -r requirements.txt
```

## MySQL Setup

Install MySQL if it is not already installed:

```bash
sudo apt update
sudo apt install mysql-server
sudo service mysql start
```

Enable local data loading:

```bash
mysql -u root -e "SET GLOBAL local_infile = 1;"
```

Before running the SQL script, update the dataset path in `sql/analysis.sql` if required.

Then run:

```bash
mysql --local-infile=1 -u root < sql/analysis.sql
```

## Run the Project

Start Jupyter Notebook:

```bash
jupyter notebook
```

Run the notebooks in this order:

1. `notebooks/01_data_cleaning.ipynb`
2. `notebooks/02_eda.ipynb`
3. `notebooks/03_modeling.ipynb`

## Project Structure

```text
credit-risk-analysis/
├── data/
│   ├── raw/
│   │   ├── german.data
│   │   └── german.names
│   └── processed/
│       ├── german_credit_processed.csv
│       ├── train_set.csv
│       └── test_set.csv
├── notebooks/
│   ├── 01_data_cleaning.ipynb
│   ├── 02_eda.ipynb
│   └── 03_modeling.ipynb
├── sql/
│   └── analysis.sql
├── src/
│   └── preprocessing.py
├── requirements.txt
├── README.md
└── .gitignore
```

## Tech Stack

Python, Pandas, NumPy, Matplotlib, Seaborn, Scikit-learn, MySQL, Jupyter Notebook.
