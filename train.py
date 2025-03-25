import os
import sys
import json
from detectron2.engine import DefaultTrainer
from detectron2.config import get_cfg
from detectron2 import model_zoo
from detectron2.data import MetadataCatalog, DatasetCatalog
from detectron2.data.datasets import register_coco_instances


def check_dataset_paths(train_json, val_json, train_images, val_images):

    if not os.path.isfile(train_json):
        print(f"[ERROR] train.json 文件不存在: {train_json}")
        sys.exit(1)
    if not os.path.isfile(val_json):
        print(f"[ERROR] val.json 文件不存在: {val_json}")
        sys.exit(1)
    if not os.path.isdir(train_images):
        print(f"[ERROR] 训练图片目录不存在: {train_images}")
        sys.exit(1)
    if not os.path.isdir(val_images):
        print(f"[ERROR] 验证图片目录不存在: {val_images}")
        sys.exit(1)

    print("数据集路径检查完毕。")


def setup_cfg(base_dir):
    """
    设置并返回 Detectron2 的 cfg 配置。
    """

    # 官方预训练配置
    cfg = get_cfg()
    cfg.merge_from_file(
        model_zoo.get_config_file("COCO-InstanceSegmentation/mask_rcnn_R_50_FPN_3x.yaml")
    )

    # 使用 CPU 
    cfg.MODEL.DEVICE = "cpu"

    # 数据集名称
    cfg.DATASETS.TRAIN = ("my_dataset_train",) #训练集
    cfg.DATASETS.TEST = ("my_dataset_val",)

    # 训练超参数
    cfg.DATALOADER.NUM_WORKERS = 0  
    cfg.SOLVER.IMS_PER_BATCH = 2       # 每 batch 2 张图
    cfg.SOLVER.BASE_LR = 0.00025       # 学习率
    cfg.SOLVER.MAX_ITER = 300          # 迭代次数
    cfg.MODEL.ROI_HEADS.BATCH_SIZE_PER_IMAGE = 128
    cfg.MODEL.ROI_HEADS.NUM_CLASSES = 1  # 只有 1 类：leaf

    # 加载 COCO 预训练权重
    cfg.MODEL.WEIGHTS = model_zoo.get_checkpoint_url(
        "COCO-InstanceSegmentation/mask_rcnn_R_50_FPN_3x.yaml"
    )

    # 输出目录
    cfg.OUTPUT_DIR = os.path.join(base_dir, "output")
    os.makedirs(cfg.OUTPUT_DIR, exist_ok=True)

    return cfg


def main():
    # 获取当前文件夹路径
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    # 设置数据集路径
    dataset_root = os.path.join(BASE_DIR, "dataset")
    train_json = os.path.join(dataset_root, "annotations", "train.json")
    val_json   = os.path.join(dataset_root, "annotations", "val.json")
    train_imgs = os.path.join(dataset_root, "images")
    val_imgs   = os.path.join(dataset_root, "images")

    # 检查路径是否正确
    check_dataset_paths(train_json, val_json, train_imgs, val_imgs)

    # 注册 COCO 数据集
    print("注册 COCO 数据集 ...")
    register_coco_instances("my_dataset_train", {}, train_json, train_imgs)
    register_coco_instances("my_dataset_val", {}, val_json, val_imgs)
    print("数据集 'my_dataset_train' 和 'my_dataset_val' 注册完成。")

 
    from detectron2.data import DatasetCatalog
    train_dicts = DatasetCatalog.get("my_dataset_train")
    val_dicts   = DatasetCatalog.get("my_dataset_val")
    print(f"训练集大小: {len(train_dicts)} 张图")
    print(f"验证集大小: {len(val_dicts)} 张图")

    # 设置并获取 cfg
    cfg = setup_cfg(BASE_DIR)

    # 打印部分关键信息
    print("最终的训练配置如下：")
    print(cfg.dump())

    # 开始训练
    print("开始训练 ...")
    trainer = DefaultTrainer(cfg)
    trainer.resume_or_load(resume=False)
    trainer.train()
    print("训练结束。")

    # 训练结束后，保存 config.yaml
    config_path = os.path.join(cfg.OUTPUT_DIR, "config.yaml")
    with open(config_path, "w") as f:
        f.write(cfg.dump())
    print(f"训练配置已保存到: {config_path}")


if __name__ == "__main__":
    main()
