"""Validated, local-only interchange for FrameCut generative transition jobs."""
import base64
import binascii
import math
import struct
import uuid

PRESETS = frozenset(('custom','zoomIn','zoomOut','push','pull','flyThrough','orbit','smartMove','styleMorph','moneyVeil','slideLeft','slideRight','confetti','goldConfetti','rise','dive','smokeDrift'))
MAX_IMAGE_BYTES = 3_000_000


def validate_job(data):
    """Reject malformed/unbounded requests before loading any neural model."""
    if not isinstance(data,dict) or data.get('schemaVersion')!=1:
        raise ValueError('Unsupported FrameCut generation job version')
    for key in ('jobID','fromClipID','toClipID'):
        try:uuid.UUID(data[key])
        except (KeyError,TypeError,ValueError,AttributeError) as error:raise ValueError('Invalid job/clip identity') from error
    if data['fromClipID']==data['toClipID']:raise ValueError('Two different adjacent clips are required')
    if data.get('preset') not in PRESETS:raise ValueError('Unknown preset')
    prompt=data.get('prompt')
    if not isinstance(prompt,str) or not prompt.strip() or len(prompt)>2000:raise ValueError('Provide a prompt of at most 2000 characters')
    for key in ('width','height'):
        value=data.get(key)
        if type(value) is not int or not 64<=value<=768 or value%32:raise ValueError('Dimensions must be multiples of 32 between 64 and 768')
    frames=data.get('numFrames')
    if type(frames) is not int or not 17<=frames<=97 or (frames-1)%8:raise ValueError('Frame count must be 8n+1 between 17 and 97')
    if data.get('framesPerSecond')!=24:raise ValueError('This generation profile requires 24 fps')
    seed=data.get('seed')
    if type(seed) is not int or not 0<=seed<=4294967295:raise ValueError('Invalid seed')
    duration=data.get('transitionDuration')
    if type(duration) not in (int,float) or not math.isfinite(duration) or not 0.05<=duration<=5:raise ValueError('Invalid transition duration')
    for key in ('firstFramePNG','lastFramePNG'):
        encoded=data.get(key)
        if not isinstance(encoded,str) or len(encoded)>4*((MAX_IMAGE_BYTES+2)//3):raise ValueError('Image payload too large or missing')
        try:image=base64.b64decode(encoded,validate=True)
        except (ValueError,binascii.Error) as error:raise ValueError('Malformed image encoding') from error
        if len(image)<33 or len(image)>MAX_IMAGE_BYTES or image[:8]!=b'\x89PNG\r\n\x1a\n' or image[12:16]!=b'IHDR':raise ValueError('Expected bounded PNG endpoints')
        w,h=struct.unpack('>II',image[16:24])
        if (w,h)!=(data['width'],data['height']):raise ValueError('Endpoint size does not match the generation request')
    return dict(data)


def validate_local_profile(job):
    """Bound decoder work on the tested 8 GB Mac; not a hard RAM guarantee."""
    if job['width']*job['height']*job['numFrames']>4_300_000:
        raise ValueError('Request exceeds the tested local memory profile. Shorten the transition or use a smaller endpoint resolution; this Mac profile is limited to 4.3 million pixel-frames.')
