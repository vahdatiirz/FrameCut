import json,os,tempfile,unittest
from pathlib import Path

@unittest.skipUnless(os.environ.get('FRAMECUT_TEST_JOB'),'Requires explicit local model integration test')
class FullModelTests(unittest.TestCase):
    def test_real_model_renders_interior_and_continuous_anchored_endpoints(self):
        import imageio.v2 as imageio
        import numpy as np
        from PIL import Image
        import base64,io
        from framecut_render import render_job
        from framecut_generation import validate_job
        job=validate_job(json.loads(Path(os.environ['FRAMECUT_TEST_JOB']).read_text()))
        result=render_job(job,os.environ['FRAMECUT_MODEL_DIR'],os.environ['FRAMECUT_TEXT_MODEL_DIR'],os.environ['FRAMECUT_RUNTIME_ROOT'],os.environ['FRAMECUT_TEST_OUTPUT'])
        self.assertEqual(result['status'],'rendered')
        reader=imageio.get_reader(result['movie'])
        frames=np.array([frame for frame in reader]);reader.close()
        self.assertEqual(frames.shape,(job['numFrames'],job['height'],job['width'],3))
        first=np.array(Image.open(io.BytesIO(base64.b64decode(job['firstFramePNG']))).convert('RGB')).astype(float)
        last=np.array(Image.open(io.BytesIO(base64.b64decode(job['lastFramePNG']))).convert('RGB')).astype(float)
        self.assertLess(np.abs(frames[0].astype(float)-first).mean(),10)
        self.assertLess(np.abs(frames[-1].astype(float)-last).mean(),10)
        raw=imageio.get_reader(result['rawMovie']);middle=raw.get_data(job['numFrames']//2).astype(float);raw.close()
        baseline=(first+last)/2
        self.assertGreater(np.abs(middle-baseline).mean(),3,'The model output must not be a linear crossfade')
        self.assertGreater(frames[1:-1].std(),5,'Reject blank generation')
