import argparse
import os
import requests
import sys

def main():
    parser = argparse.ArgumentParser(description="Send file to manager")
    parser.add_argument("--path", required=True, help="Path to the file to upload")
    parser.add_argument("--main", help="Name of the main script (defaults to filename)")
    
    args = parser.parse_args()
    
    file_path = args.path
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
        
    main_name = args.main
    if not main_name:
        main_name = os.path.basename(file_path)
        
    url = "http://127.0.0.1:8082/update"
    
    try:
        with open(file_path, "rb") as f:
            files = {"file": f}
            data = {"main": main_name}
            response = requests.post(url, files=files, data=data)
            
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()