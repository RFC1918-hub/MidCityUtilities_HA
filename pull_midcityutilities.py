import requests
import sys
from bs4 import BeautifulSoup
import json

# Read arguments from command line <username> <password>
if len(sys.argv) != 3:
    print("Usage: python pull_midcityutilities.py <username> <password>")
    sys.exit(1)
username = sys.argv[1]
password = sys.argv[2]
# Set up the URL for the request
login_url = "https://buyprepaid.midcityutilities.co.za/ajax/login"
meter_url = "https://buyprepaid.midcityutilities.co.za/meters"

# Login to the website
session = requests.Session()
payload = {
    'email': username,
    'password': password
}

response = session.post(login_url, data=payload)
# If response is not "{"ok":true,"success":true}" then exit
if response.text != '{"ok":true,"success":true}':
    print("Login failed. Please check your username and password.")
    sys.exit(1)

# Get the meter data
response = session.get(meter_url)
if response.status_code != 200:
    print("Failed to retrieve meter data.")
    sys.exit(1)

# Parse the HTML content
soup = BeautifulSoup(response.text, 'html.parser')

# Find the meter data in the HTML
meter_data = soup.find('div', {'id': 'meter-balance-text'})
if meter_data is None:
    print("Failed to find meter data in the response.")
    sys.exit(1)

# Extract the meter balance
meter_balance = meter_data.find_all('div', class_="text-left")[0].text.strip()
predicted_zero_balance = meter_data.find_all('div', class_="text-left")[2].text.strip()

# Return the meter balance and predicted zero balance
result = {
    "meter_balance": meter_balance,
    "predicted_zero_balance": predicted_zero_balance
}

print(json.dumps(result))

# Close the session
session.close()