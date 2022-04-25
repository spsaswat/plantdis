# DetDis file

#taking the file path from command line
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-v","--view",action="store_true")
parser.add_argument("file_path")
args = parser.parse_args()
# storing the file path in a variable
f_path = args.file_path
if('/' not in f_path):
    if('.JPG' not in f_path):
        f_path = f_path + '.JPG'
    f_path = 'test/' + f_path

import os

# checking if the file exists
assert os.path.exists(f_path), "The file could not be found, "+str(f_path)




import sys


import tensorflow as tf

# print('the tensorflow version is', tf. __version__)

import cv2
import numpy as np

import requests
import gdown

import matplotlib.pyplot as plt
import matplotlib.image as mpimg

from tensorflow import keras
from pathlib import Path



path = Path('pd_densenet201_6.h5')
if (not path.is_file()):
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



img = mpimg.imread(str(f_path))
img3 = cv2.resize(img,(256,256))
img4 = np.reshape(img3,[1,256,256,3])
img4 = img4/255
# plt.imshow(img3)
model = keras.models.load_model('pd_densenet201_6.h5')

# using the model to predict disease
disease = np.argmax(model.predict(img4),axis=1)
# disease is a list and at 0th index is the disease with highest probability 
print('')

# Splitting the predicted class to plant and disease name.
plant, dis = diseases[disease[0]].split('___')
print((plant+','+dis).lower())


if args.view:
    # Setting up plt and showing the image used for prediction
    fig = plt.figure("Leaf Diagnosed")
    finalMsg = "Predicted plant is "+plant+" & disease is "+dis
    plt.title(finalMsg)
    plt.imshow(img3)
    plt.show()
