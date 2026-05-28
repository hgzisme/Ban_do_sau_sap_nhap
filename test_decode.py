import json
import base64
import struct

data = [
    {
        'region': 'Northern Midlands and Mountain Areas',
        'y': ['Tỉnh Lai Châu','Tỉnh Cao Bằng','Tỉnh Điện Biên','Tỉnh Lạng Sơn','Tỉnh Sơn La','Tỉnh Lào Cai','Tỉnh Thái Nguyên','Tỉnh Tuyên Quang','Tỉnh Bắc Ninh','Tỉnh Phú Thọ'],
        'bdata': 'AAAAAGRJH0EAAAAAfn0hQQAAAACGiiRBAAAAANDlKkEAAAAAq241QQAAAABhJDtBAAAAAEF1O0EAAAAANnY8QQAAAIA0nUtBAAAAALewTkE='
    },
    {
        'region': 'North Central and Central Coastal Areas',
        'y': ['Thành phố Huế','Tỉnh Hà Tĩnh','Tỉnh Quảng Trị','Tỉnh Quảng Ngãi','Tỉnh Khánh Hòa','Thành phố Đà Nẵng','Tỉnh Nghệ An','Tỉnh Thanh Hóa'],
        'bdata': 'AAAAAJrdNUEAAAAAdcM4QQAAAAD9izxBAAAAgC1+QEEAAAAA8R1BQQAAAACOY0dBAAAAAMc7TUEAAADAa39QQQ=='
    },
    {
        'region': 'Red River Delta',
        'y': ['Tỉnh Quảng Ninh','Tỉnh Hưng Yên','Tỉnh Ninh Bình','Thành phố Hải Phòng','Thủ đô Hà Nội'],
        'bdata': 'AAAAAGfZNkEAAACAozhLQQAAAADa1FBBAAAAAM/KUUEAAABgjMxgQQ=='
    },
    {
        'region': 'Mekong River Delta',
        'y': ['Tỉnh Cà Mau','Thành phố Cần Thơ','Tỉnh Vĩnh Long','Tỉnh Đồng Tháp','Tỉnh An Giang'],
        'bdata': 'AAAAACjjQ0EAAAAAZAVQQQAAAEDLPVBBAAAAgJ+rUEEAAACAK+RSQQ=='
    },
    {
        'region': 'Southeast',
        'y': ['Tỉnh Tây Ninh','Thành phố Đồng Nai','Thành phố Hồ Chí Minh'],
        'bdata': 'AAAAAM3TSEEAAAAAJCJRQQAAAMA0tWpB'
    },
    {
        'region': 'Central Highlands',
        'y': ['Tỉnh Đắk Lắk','Tỉnh Gia Lai','Tỉnh Lâm Đồng'],
        'bdata': 'AAAAgNKISUEAAACAZldLQQAAAIBzjE1B'
    }
]

for d in data:
    b = base64.b64decode(d['bdata'])
    floats = struct.unpack(f'<{len(b)//8}d', b)
    print(f"\nRegion: {d['region']}")
    for prov, pop in zip(d['y'], floats):
        print(f"{prov}: {int(pop):,}")
