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

import random

from tensorflow import keras
from pathlib import Path

from mlhub.pkg import mlask, mlcat

# for ignoring the warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
warnings.filterwarnings("ignore")

model_name = 'pdorft_efficientnetb2_3.h5'
path = Path(model_name)


mlcat("PlantDis", """\
    PlantDis is a mlhub package for detecting plant disease from image of a leaf.\n
    This library is based on pretrained-model which itself is based on EfficientNetB2.\n
    For Details you can visit:-\n
    \nhttps://github.com/spsaswat/plantdis/blob/main/ipynb/\n
    """)


# rechecking if the file was successfully downloaded
if (not path.is_file()):
    mlask(end='\n',
      prompt="Model Not Found. Press Enter to download the model(130 MB)")
    url = 'https://drive.google.com/uc?id=1mAxgMNJZ2c_5c16YdAaQWZ5H06BuBAF9'
    r = requests.get(url, allow_redirects=True)
    output = model_name
    gdown.download(url, output, quiet=False)
# if file size is less than 10MB then it means
# the file is corrupted, so download again
elif ((os.path.getsize(path) / 1000) < 10000):
  mlask(end='\n',
    prompt="Model file may be corrupted. Press Enter to download the model(130 MB)")
  url = 'https://drive.google.com/uc?id=1mAxgMNJZ2c_5c16YdAaQWZ5H06BuBAF9'
  r = requests.get(url, allow_redirects=True)
  output = model_name
  gdown.download(url, output, quiet=False)

# all the disease classes
diseases=['Apple___Apple_scab','Apple___Black_rot','Apple___Cedar_apple_rust','Apple___healthy',
 'Corn___Gray_leaf_spot','Corn___Common_rust','Corn___Northern_Leaf_Blight','Corn___healthy',
 'Orange___Citrus_greening',
 'Potato___Early_blight', 'Potato___Late_blight', 'Potato___healthy',
 'Tomato___Bacterial_spot',
 'Tomato___Early_blight',
 'Tomato___Late_blight',
 'Tomato___Leaf_Mold',
 'Tomato___Septoria_leaf_spot',
 'Tomato___Spider_mites Two-spotted_spider_mite',
 'Tomato___Target_Spot',
 'Tomato___Yellow_Curl_Virus',
 'Tomato___Tomato_mosaic_virus',
 'Tomato___healthy']


model = keras.models.load_model(model_name)

# collecting names of images in the test folder
t_path = Path('test')
from os import listdir
from os.path import isfile, join
onlyfiles = [f for f in listdir(t_path) if isfile(join(t_path, f))]
from os import walk
t_img_names = next(walk(t_path), (None, None, []))[2]

n=3

# generating n unique random numbers
r_n = random.sample(range(0, 32), n)

for i in range(n):
  # Read Image
  img = mpimg.imread('test/'+t_img_names[r_n[i]])

  # bringing the image to format used for model training 
  # resizing to match input shape of efficientb2
  img3 = cv2.resize(img,(260,260))
  # expanding dimension
  img4 = np.reshape(img3,[1,260,260,3])

  # using the model to predict disease
  disease = np.argmax(model.predict(img4),axis=1)
  # disease is a list and at 0th index is the disease with highest probability 
  print('The image Name is',t_img_names[r_n[i]][:-4])
  # Splitting the predicted class to plant and disease name.
  plant, dis = diseases[disease[0]].split('___')
  actual = 'Actual:- ' + t_img_names[r_n[i]][:-4]
  # Splitting the predicted class to plant and disease name.
  plant, dis = diseases[disease[0]].split('___')
  if(dis.lower()=='healthy'):
    finalAnnot = actual + '\n'+"Predicted plant is "+plant+" & it is "+dis
  else:
    finalAnnot = actual + '\n'+"Predicted plant is "+plant+" & disease is "+dis
  print(finalAnnot)
  if(i!=(n-1)):
    print('')

  # Setting up plt and showing the image used for prediction
  fig = plt.figure("PlantDis Demo")
  plt.title(finalAnnot)
  plt.imshow(img3)
  plt.show()




