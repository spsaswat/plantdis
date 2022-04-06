# Demo file
import warnings
import os
import tensorflow as tf

import cv2
import numpy as np

import requests
import gdown

import matplotlib.pyplot as plt
import matplotlib.image as mpimg

from tensorflow import keras
from pathlib import Path

from mlhub.pkg import mlask, mlcat

# for ignoring the warnings
tf.get_logger().setLevel('ERROR')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
warnings.filterwarnings("ignore")

print('the tensorflow version is', tf. __version__)

path = Path('pd_densenet201_6.h5')
if path.is_file():
    print('Model downloaded already')
else:
    mlcat("plantdis", """\
    plantdis is a mlhub package for detecting plant disease from image of a leaf.\n
    This library is based on pretrained-model which is based on DenseNet201.\n
    For Details you can visit:-\n
    \nhttps://github.com/spsaswat/plantdis/blob/main/ipynb/\n
    """)
    mlask(end='\n',
      prompt="Press Enter to download the model(248MB)")
    url = 'https://drive.google.com/uc?id=1m0bU-NCqzfjO37HFBEm4-2YmTQwQzil6'
    r = requests.get(url, allow_redirects=True)
    output = 'pd_densenet201_6.h5'
    gdown.download(url, output, quiet=False)

diseases=['Apple___Apple_scab','Apple___Black_rot','Apple___Cedar_apple_rust','Apple___healthy','Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot','Corn_(maize)___Common_rust','Corn_(maize)___Northern_Leaf_Blight','Corn_(maize)___healthy','Potato___Early_blight',
 'Potato___Late_blight',
 'Potato___healthy',
 'Tomato___Bacterial_spot',
 'Tomato___Early_blight',
 'Tomato___Late_blight',
 'Tomato___Leaf_Mold',
 'Tomato___Septoria_leaf_spot',
 'Tomato___Spider_mites Two-spotted_spider_mite',
 'Tomato___Target_Spot',
 'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
 'Tomato___Tomato_mosaic_virus',
 'Tomato___healthy']


# Read Image
img = mpimg.imread('test/CornCommonRust1.JPG')

# bringing the image to format used for model training 
img3 = cv2.resize(img,(256,256))
img4 = np.reshape(img3,[1,256,256,3])
img4 = img4/255

model = keras.models.load_model('pd_densenet201_6.h5')
# using the model to predict disease
disease = np.argmax(model.predict(img4),axis=1)
# disease is a list and at 0th index is the disease with highest probability 
print('The file path is:- test/CornCommonRust1.JPG')
print('')

# Splitting the predicted class to plant and disease name.
plant, dis = diseases[disease[0]].split('___')
print("The predicted plant is",plant,"and disease is",dis)

# Setting up plt and showing the image used for prediction
plt.title("Predicted:- "+ diseases[disease[0]])
plt.imshow(img3)
plt.show()
