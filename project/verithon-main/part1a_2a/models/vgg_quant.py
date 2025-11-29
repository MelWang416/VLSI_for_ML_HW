
import torch
import torch.nn as nn
import math
from models.quant_layer_2b import *
from models.quant_layer_4b import *

cfg = {
    'VGG16_quant_4b': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 8, 8, 512, 'M', 512, 512, 512, 'M'],
    'VGG16_quant_2b': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 16, 16, 512, 'M', 512, 512, 512, 'M']
}


class VGG_quant(nn.Module):
    def __init__(self, x_bit, vgg_name):
        super(VGG_quant, self).__init__()
        self.x_bit = x_bit
        self.features = self._make_layers(cfg[vgg_name])
        self.classifier = nn.Linear(512, 10)
        

    def forward(self, x):
        out = self.features(x)
        out = out.view(out.size(0), -1)
        out = self.classifier(out)
        return out

    def _make_layers(self, cfg):
        layers = []
        in_channels = 3
        for x in cfg:
            if x == 'M':
                layers += [nn.MaxPool2d(kernel_size=2, stride=2)]
            elif x == 'F':  # This is for the 1st layer
                layers += [nn.Conv2d(in_channels, 64, kernel_size=3, padding=1, bias=False),
                           nn.BatchNorm2d(64),
                           nn.ReLU(inplace=True)]
                in_channels = 64
            else:
                if self.x_bit == 4:
                    if in_channels == 8 and x == 8:
                        layers += [QuantConv2d_4b(in_channels, x, kernel_size=3, padding=1),
                                   nn.ReLU(inplace=True)]
                        in_channels = x
                    else:
                        layers += [QuantConv2d_4b(in_channels, x, kernel_size=3, padding=1),
                                   nn.BatchNorm2d(x),
                                   nn.ReLU(inplace=True)]
                        in_channels = x
                else:
                    if in_channels == 16 and x == 16:
                        layers += [QuantConv2d_2b(in_channels, x, kernel_size=3, padding=1),
                                   nn.ReLU(inplace=True)]
                        in_channels = x
                    else:
                        layers += [QuantConv2d_2b(in_channels, x, kernel_size=3, padding=1),
                                   nn.BatchNorm2d(x),
                                   nn.ReLU(inplace=True)]
                        in_channels = x
                    
        layers += [nn.AvgPool2d(kernel_size=1, stride=1)]
        return nn.Sequential(*layers)

    def show_params(self):
        for m in self.modules():
            if isinstance(m, QuantConv2d_4b):
                m.show_params()
            if isinstance(m, QuantConv2d_2b):
                m.show_params()
    

def VGG16_quant_4b(**kwargs):
    model = VGG_quant(x_bit=4, vgg_name = 'VGG16_quant_4b', **kwargs)
    return model
    
def VGG16_quant_2b(**kwargs):
    model = VGG_quant(x_bit=2, vgg_name = 'VGG16_quant_2b', **kwargs)
    return model



