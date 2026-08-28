import requests
import json

def test_ocr():
    url = 'https://api.ocr.space/parse/image'
    payload = {
        'apikey': 'helloworld',
        'language': 'eng',
        'isOverlayRequired': False
    }
    with open('C:\\Users\\abdulrahman kitiavi\\.gemini\\antigravity\\brain\\7191e801-674f-4bb1-b4ec-cad4d5827d37\\.user_uploaded\\media_1786957932510.png', 'rb') as f:
        r = requests.post(url,
                          files={'filename': f},
                          data=payload)
    print(r.status_code)
    print(r.text)

if __name__ == '__main__':
    test_ocr()
