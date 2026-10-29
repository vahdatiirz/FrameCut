import unittest
import numpy as np
import mlx.core as mx
from framecut_mlx import t5_relative_position_bucket

class TextPositionTests(unittest.TestCase):
    def test_preserves_near_words_and_logarithmic_long_range_t5_buckets(self):
        # Official T5 defaults: bidirectional 32 buckets, max_distance 128.
        distances=mx.array([0,-1,-7,-8,-16,-32,-64,-128,-256,1,8,16,32,64,128])
        actual=np.array(t5_relative_position_bucket(distances))
        np.testing.assert_array_equal(actual,[0,1,7,8,10,12,14,15,15,17,24,26,28,30,31])
