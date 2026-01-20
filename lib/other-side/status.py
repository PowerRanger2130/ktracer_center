import argparse
import requests
import sys

def main():
    parser = argparse.ArgumentParser(description="Check status of a main script")
    parser.add_argument("--main", required=True, help="Name of the main script")
    
    args = parser.parse_args()
    
    url = "http://127.0.0.1:8082/status"
    params = {"main": args.main}
    
    try:
        response = requests.get(url, params=params)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
