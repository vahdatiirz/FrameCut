import unittest
import mlx.core as mx
import mlx.nn as nn
import numpy as np
from framecut_mlx import stream_quantized_load

class Tiny(nn.Module):
    def __init__(self):
        super().__init__();self.linear=nn.Linear(64,16);self.norm=nn.LayerNorm(16)
    def __call__(self,x):return self.norm(self.linear(x))

class QuantizedLoadTests(unittest.TestCase):
    def weights(self):
        return {'linear.weight':mx.arange(1024).reshape(16,64).astype(mx.float16)/1024-0.5,'linear.bias':mx.arange(16).astype(mx.float16)/20,'norm.weight':mx.full((16,),1.5),'norm.bias':mx.full((16,),0.3)}
    def test_streamed_weights_keep_the_real_linear_and_normalization_response(self):
        reference=Tiny();reference.load_weights(list(self.weights().items()),strict=True)
        model=stream_quantized_load(Tiny(),self.weights())
        x=mx.arange(64).astype(mx.float16)[None,:]/64
        np.testing.assert_allclose(np.array(model(x)),np.array(reference(x)),atol=0.06,rtol=0.06)
        self.assertIsInstance(model.linear,nn.QuantizedLinear)
    def test_rejects_missing_checkpoint_parameters(self):
        with self.assertRaises(ValueError):stream_quantized_load(Tiny(),{'linear.weight':mx.ones((16,64))})
