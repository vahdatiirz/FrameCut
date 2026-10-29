import unittest
from framecut_generation import validate_local_profile

class LocalProfileTests(unittest.TestCase):
    def test_accepts_measured_small_profiles_and_rejects_unbounded_decoder_work(self):
        validate_local_profile({'width':512,'height':288,'numFrames':25})
        validate_local_profile({'width':384,'height':224,'numFrames':49})
        with self.assertRaisesRegex(ValueError,'local memory profile'):
            validate_local_profile({'width':768,'height':768,'numFrames':97})
