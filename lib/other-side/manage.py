import argparse
import requests
import sys

def main():
    parser = argparse.ArgumentParser(description="Manage (start/stop) a main script")
    parser.add_argument("command", choices=["start", "stop"], help="Command to execute")
    parser.add_argument("--main", required=True, help="Name of the main script")
    
    args = parser.parse_args()
    
    base_url = "http://127.0.0.1:8082"
    url = f"{base_url}/{args.command}"
    params = {"main": args.main}
    
    try:
        response = requests.post(url, params=params)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()