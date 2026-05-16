"""
GCP BigQuery Data Extraction Script
Author: Student
Description: Connects to BigQuery using a specific Service Account 
             and extracts US natality data from a public dataset.
"""

from google.auth import compute_engine
from google.cloud import bigquery

def main():
    # Define the service account email used by the VM instance
    # Note: Replace with your actual project ID if running outside the lab environment
    service_account_email = 'bigquery-qwiklab@qwiklabs-gcp-00-4d735534a7a3.iam.gserviceaccount.com'
    project_id = 'qwiklabs-gcp-00-4d735534a7a3'

    print("Initializing Google Compute Engine credentials...")
    credentials = compute_engine.Credentials(service_account_email=service_account_email)

    print("Connecting to BigQuery Client...")
    client = bigquery.Client(project=project_id, credentials=credentials)

    # SQL Query to extract and aggregate baby data from public samples
    query = """
    SELECT
      year,
      COUNT(1) as num_babies
    FROM
      `publicdata.samples.natality`
    WHERE
      year > 2000
    GROUP BY
      year
    ORDER BY
      year DESC
    """

    print("Executing query on BigQuery public dataset...")
    try:
        # Run the query and convert the results directly to a Pandas DataFrame
        df = client.query(query).to_dataframe()
        
        print("\n--- Query Results Successful ---")
        print(df.to_string(index=False))
        print("---------------------------------\n")
        
    except Exception as e:
        print(f"An error occurred while executing the query: {e}")

if __name__ == "__main__":
    main()
