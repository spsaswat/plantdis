# Diagnose file

import warnings

# taking the file path from command line

import argparse
import re
import os

# Ensure paths are relative to the user's cwd.

from mlhub.pkg import get_cmd_cwd
os.chdir(get_cmd_cwd())

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--view', action='store_true')
parser.add_argument('file_path')
args = parser.parse_args()

# regular expression for proper image name with extension

pattern = '[^\\s]+(.*?)\\.(jpg|jpeg|png|gif)$'

# storing the file path in a variable

f_path = args.file_path

# checking if the image has proper extensions

if not re.search(pattern, f_path.lower()):
    raise Exception('Please add proper image extension')

# checking if the file exists

assert os.path.exists(f_path), 'The file could not be found, ' \
    + str(f_path)

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
from mlhub.pkg import mlask

# for ignoring the warnings

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
warnings.filterwarnings('ignore')

model_name = 'pdorft_efficientnetb2_3.h5'
path = Path(model_name)

# rechecking if the file was successfully downloaded

if not path.is_file():
    print ('Model file could not be found, Downloading again..')
    url = \
        'https://drive.google.com/uc?id=1mAxgMNJZ2c_5c16YdAaQWZ5H06BuBAF9'
    r = requests.get(url, allow_redirects=True)
    output = model_name
    gdown.download(url, output, quiet=False)
    print ('')
elif os.path.getsize(path) / 1000 < 10000:

# if file size is less than 10MB then it means
# the file is corrupted, so download again

    print ('Model file corrupted, Downloading again..')
    url = \
        'https://drive.google.com/uc?id=1mAxgMNJZ2c_5c16YdAaQWZ5H06BuBAF9'
    r = requests.get(url, allow_redirects=True)
    output = model_name
    gdown.download(url, output, quiet=False)
    print ('')

# all the disease classes

diseases = [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Corn___Gray_leaf_spot',
    'Corn___Common_rust',
    'Corn___Northern_Leaf_Blight',
    'Corn___healthy',
    'Orange___Citrus_greening',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Yellow_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
    ]

img = mpimg.imread(str(f_path))

# bringing the image to format used for model training
# resizing to match input shape of efficientb2

img3 = cv2.resize(img, (260, 260))

# expanding dimension

img4 = np.reshape(img3, [1, 260, 260, 3])
model = keras.models.load_model(model_name)

# using the model to predict disease

disease = np.argmax(model.predict(img4), axis=1)

# disease is a list and at 0th index is the disease with highest probability

# Splitting the predicted class to plant and disease name.

(plant, dis) = diseases[disease[0]].split('___')
print ((plant + ',' + dis).lower())

if args.view:

    # Setting up plt and showing the image used for prediction

    fig = plt.figure('Leaf Diagnosed')
    if dis.lower() == 'healthy':
        finalAnnot = 'Predicted plant is ' + plant + ' & it is ' + dis
    else:
        finalAnnot = 'Predicted plant is ' + plant + ' & disease is ' \
            + dis
    plt.title(finalAnnot)
    plt.imshow(img3)
    plt.show()
