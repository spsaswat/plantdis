<h1 align="center"> A Plant Disease Detector App based on Nested Transfer Learning </h1>
<p align="center">
The objective of the project is to identify plant disease by using image of a plant leaf using deep learning model. Currently 5 Plants are supported Apple, Corn, Orange, Potato and Tomato. The Whole project has four components:- <a href = "https://github.com/spsaswat/plantdis/tree/main/ipynb">Deep Learning</a>(Using Tensorflow), <a href = "https://github.com/spsaswat/plantdis/tree/main/mlhub">Command Line Interaction</a>(Using ML-HUB), <a href = "https://github.com/spsaswat/plantdis/tree/main/plantdis_flutter">Linux Desktop App</a>(MLHUB backend), and <a href = "https://github.com/spsaswat/plantdis/tree/main/plantdis_mob">Android App</a>(Tflite backend). This project was initially started as a requirement of the course COM4560(ANU), under the supervision of Prof. <a href = "https://cecs.anu.edu.au/people/graham-williams">Graham Williams</a>.
</p>

<h2 align="center"> Mobile App Demo </h2>
<br>
<p align="center">
  <img src="https://github.com/spsaswat/plantdis/raw/main/op_m_readme/output_compressed.gif" alt="Plantdis Demo App">
</p>

<h2 align="center"> Desktop App Demo </h2>
<br><p align="center"> <img src="https://github.com/spsaswat/plantdis/blob/main/op_m_readme/desk_demo.gif" alt="Desktop App Demo"> </p>

<h2 align="center"> Results on test images </h2>
<br><img src="https://github.com/spsaswat/plantdis/blob/main/op_m_readme/test_img_22_eff_or.jpg" alt="Desktop App Demo">

<h2 align="center"> Nested Transfer Learning Concept Map </h2>
<br><img src="https://github.com/spsaswat/plantdis/blob/main/op_m_readme/nested%20transfer%20learning_f_github.png" alt="Nested Transfer Learning Concept Map">
The knowledge in the diagram refers to weights. The weights in model layers will be nested.

<h2 align="center"> Trained Models with weights(h5) </h2>
<p align="center">
1) <a href = "https://drive.google.com/file/d/11nEATbNc65LhLRJx1TvST9V9dh_ZG59j/view?usp=sharing">Transfer Learning Based EfficientB2 - 21 Classes</a>
<br>
2) <a href = "https://drive.google.com/file/d/1mAxgMNJZ2c_5c16YdAaQWZ5H06BuBAF9/view?usp=sharing">Nested Tansfer Learning Based EfficientB2 - 22 Classes</a>
</p>

<h2 align="center"> Dataset Sources </h2>
<p align="center">
Plant Village Dataset - https://data.mendeley.com/datasets/tywbtsjrjv/1
<br>Banana Leaf images - https://github.com/godliver/source-code-BBW-BBS/
</p>

## Citation
If this repository is useful for your research, please cite as below:
```
@article{panda2022PlantDis,
  title={PlantDis: A Plant Disease Detector App 
  based on Nested Transfer Learning},
  author={Panda, Saswat and Williams, Graham},
  year={2022},
  repository-link="https://github.com/spsaswat/plantdis"
}
```

<h3 align="center"> Funding </h3>
Starting from 11/06/2024, the project is supported by APPN (https://www.plantphenomics.org.au/). <br>
Project Lead: Saswat Panda
Co-lead: Ming-dao Chia


