# DetDis file
import sys
import os

import tensorflow as tf

print('the tensorflow version is', tf. __version__)

import cv2
import numpy as np

import requests
import gdown

import matplotlib.pyplot as plt
import matplotlib.image as mpimg

from tensorflow import keras
from pathlib import Path

path = Path('pd_densenet201_6.h5')
if path.is_file():
    print('Model downloaded already')
else:
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
# print(len(diseases))

# Read Images
print("Example of a path:-   test/CornCommonRust1.JPG")
user_input = input("Enter the path of your file: ")
assert os.path.exists(user_input), "The file could not be found, "+str(user_input)
img = mpimg.imread(str(user_input))
img3 = cv2.resize(img,(256,256))
img4 = np.reshape(img3,[1,256,256,3])
img4 = img4/255
plt.imshow(img3)
model = keras.models.load_model('pd_densenet201_6.h5')
disease = np.argmax(model.predict(img4),axis=1)
print('')
print("The predicted plant and disease are ",diseases[disease[0]])