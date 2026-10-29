import base64,copy,math,struct,unittest,uuid,zlib
from framecut_generation import validate_job

def png(width=64,height=64):
    def chunk(name,data):
        return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+bytes([220,40,20])*width)*height))+chunk(b'IEND',b'')

def fixture():
    return dict(schemaVersion=1,jobID=str(uuid.uuid4()),fromClipID=str(uuid.uuid4()),toClipID=str(uuid.uuid4()),preset='smokeDrift',prompt='Soft smoke links two scenes.',width=64,height=64,numFrames=17,framesPerSecond=24,seed=42,transitionDuration=0.5,firstFramePNG=base64.b64encode(png()).decode(),lastFramePNG=base64.b64encode(png()).decode())

class GenerationJobTests(unittest.TestCase):
    def test_valid_job_preserves_endpoint_bytes_without_mutating_input(self):
        data=fixture();before=copy.deepcopy(data);job=validate_job(data)
        self.assertEqual(job['jobID'],data['jobID']);self.assertEqual(data,before)
        self.assertEqual(base64.b64decode(job['firstFramePNG']),png())
    def test_rejects_unsupported_dimensions_frames_seed_and_identity(self):
        for key,value in [('width',65),('height',8192),('numFrames',18),('numFrames',1001),('seed',-1),('framesPerSecond',0),('schemaVersion',2),('jobID','bad'),('transitionDuration',math.nan),('transitionDuration',0),('preset','unknown'),('prompt','')]:
            data=fixture();data[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):validate_job(data)
        data=fixture();data['toClipID']=data['fromClipID']
        with self.assertRaises(ValueError):validate_job(data)
    def test_rejects_malformed_or_oversized_image_payloads(self):
        for payload in ['not base64',base64.b64encode(b'no image').decode(),base64.b64encode(png(128,64)).decode(),'A'*12000000]:
            data=fixture();data['firstFramePNG']=payload
            with self.subTest(length=len(payload)),self.assertRaises(ValueError):validate_job(data)
