import unittest
import mlx.core as mx
import numpy as np
from framecut_mlx import condition_endpoints,freeze_endpoints

class ConditioningTests(unittest.TestCase):
    def test_only_first_and_last_latent_frames_are_frozen(self):
        noise=mx.zeros((1,6,2));first=mx.full((1,2,2),2.0);last=mx.full((1,2,2),7.0)
        latents,mask=condition_endpoints(noise,first,last)
        np.testing.assert_array_equal(np.array(latents),[[[2,2],[2,2],[0,0],[0,0],[7,7],[7,7]]])
        np.testing.assert_array_equal(np.array(mask),[[1,1,0,0,1,1]])
        changed=freeze_endpoints(mx.full((1,6,2),9.0),latents,mask)
        np.testing.assert_array_equal(np.array(changed),[[[2,2],[2,2],[9,9],[9,9],[7,7],[7,7]]])
    def test_rejects_requests_without_interior_or_with_mismatched_endpoints(self):
        with self.assertRaises(ValueError):condition_endpoints(mx.zeros((1,4,2)),mx.zeros((1,2,2)),mx.zeros((1,2,2)))
        with self.assertRaises(ValueError):condition_endpoints(mx.zeros((1,6,2)),mx.zeros((1,2,2)),mx.zeros((1,3,2)))
