# PlantDis Mlhub package
This ML-HUB package detects the disease of the plant by examining a leaf. If image of a leaf is provided then this package will identify what disease it has, if any. MlHub <a href="https://github.com/spsaswat/plantdis/blob/main/MLHUB.yaml">YAML</a> file contains details about the packages and files used.

i) Install mlhub.
```
pip install mlhub
```
ii) Install the plantdis package.
```
ml install spsaswat/plantdis
```
iii) Configure plantdis, i.e, install all required packages in plantdis.
```
ml configure plantdis
```
iv) Run the demo command
```
ml demo plantdis
```
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldemo_op1.jpg" alt="demo ouput" width="800" height="500">
<br>
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldemo_op2.jpg" alt="demo ouput" width="750" height="450">
<br>
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldemo_op3.jpg" alt="demo ouput" width="750" height="450">
<br>
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldemo_op4.jpg" alt="demo ouput" width="750" height="450">

v) Run the diagnose command
```
ml diagnose plantdis leaf.png -v
```
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldiag_op1.jpg" alt="diag ouput" width="800" height="55">
<br>
<img src="https://github.com/spsaswat/plantdis/blob/main/mlhub/op_mlhub/mldiag_op2.jpg" alt="diag ouput" width="750" height="450">

For a detailed documentation please refer:- https://survivor.togaware.com/mlhub/plant-disease.html

