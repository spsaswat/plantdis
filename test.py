import os
import cv2
import torch
from detectron2.config import get_cfg
from detectron2.engine import DefaultPredictor
from detectron2.utils.visualizer import Visualizer
from detectron2.data import MetadataCatalog

def main():
    # 1. 加载训练时导出的 config.yaml
    cfg = get_cfg()
    config_path = "output/config.yaml"
    cfg.merge_from_file(config_path)

    # 2. 更新模型权重位置 (model_final.pth)
    cfg.MODEL.WEIGHTS = "output/model_final.pth"
    cfg.MODEL.DEVICE = "cpu" 
    cfg.MODEL.ROI_HEADS.SCORE_THRESH_TEST = 0.7
    cfg.MODEL.ROI_HEADS.BATCH_SIZE_PER_IMAGE = 256


    # 3. 创建预测器
    predictor = DefaultPredictor(cfg)

    # 4. 读取测试图片
    test_img = "4.jpeg" 
    im = cv2.imread(test_img)
    
    # 5. 进行推理
    outputs = predictor(im)

    # 6. 可视化结果
    metadata = MetadataCatalog.get(cfg.DATASETS.TRAIN[0])  # 载入与训练相同数据集的元数据
    v = Visualizer(im[:, :, ::-1], metadata=metadata, scale=0.5)
    out = v.draw_instance_predictions(outputs["instances"].to("cpu"))

    # 7. 结果
    result_img = out.get_image()[:, :, ::-1]
    cv2.imshow("Result", result_img)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

    
    cv2.imwrite("leaf_result.jpg", result_img)

if __name__ == "__main__":
    main()
