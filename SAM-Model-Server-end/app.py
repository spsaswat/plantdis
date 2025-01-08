import torch
import numpy as np
from flask import Flask, render_template, request, jsonify
from PIL import Image
import io
import base64
import matplotlib.pyplot as plt
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator, SamPredictor

# Load the SAM model
sam_checkpoint = "./sam_vit_h_4b8939.pth"  # Make sure the path to the model checkpoint is correct
model_type = "vit_h"

# Check if GPU is available
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Log the device being used
print(f"Using device: {device}")

# Load the SAM model onto the selected device
sam = sam_model_registry[model_type](checkpoint=sam_checkpoint)
sam.to(device=device)

# Initialize the automatic mask generator
predictor = SamPredictor(sam)

# Initialize the Flask application
app = Flask(__name__, template_folder='templates', static_folder='static', static_url_path='/static')


@app.route('/')
def index():
    """
    Renders the main index page of the web application.

    :return: The index HTML page
    """
    return render_template('index.html')



@app.route('/predict', methods=['POST'])
def predict():
    """
    Handles the image upload, processes the image with the SAM model, generates a mask,
    and returns the processed image along with device and GPU information as a JSON response.

    :return: JSON response with the processed image and device/GPU information
    """
    try:
        # Check if a file has been uploaded
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400

        x1 = request.form.get('x1', type=float)
        y1 = request.form.get('y1', type=float)
        x2 = request.form.get('x2', type=float)
        y2 = request.form.get('y2', type=float)

        print(f"Received coordinates: x1={x1}, y1={y1}, x2={x2}, y2={y2}")

        bbox_prompt = np.array([[x1, y1, x2, y2]])  # Bounding Box

        # Get the device being used (GPU or CPU)
        device_used = "GPU" if torch.cuda.is_available() else "CPU"

        # Load the uploaded image
        file = request.files['file']
        image = Image.open(file.stream).convert("RGB")
        image_np = np.array(image)

        # Log the device information
        print(f"Running on: {device_used}")

        # Generate masks using the SAM model
        predictor.set_image(image_np)
        masks, _, _ = predictor.predict(
            point_coords=None,
            point_labels=None,
            box=bbox_prompt,
            multimask_output=False,
        )

        plt.cla()

        def show_box(box, ax):
            x0, y0 = box[0], box[1]
            w, h = box[2] - box[0], box[3] - box[1]
            ax.add_patch(plt.Rectangle((x0, y0), w, h, edgecolor='green', facecolor=(0, 0, 0, 0), lw=2))

        def show_mask(mask, ax, random_color=False):
            if random_color:
                color = np.concatenate([np.random.random(3), np.array([0.6])], axis=0)
            else:
                color = np.array([30 / 255, 144 / 255, 255 / 255, 0.6])
            h, w = mask.shape[-2:]
            mask_image = mask.reshape(h, w, 1) * color.reshape(1, 1, -1)
            ax.imshow(mask_image)

        plt.imshow(image_np)
        show_mask(masks[0], plt.gca())
        show_box(bbox_prompt[0], plt.gca())
        plt.axis('off')

        # Save the image to a byte stream with tight bounding box
        buf = io.BytesIO()
        plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0)
        buf.seek(0)

        # Encode the image in base64 format
        img_base64 = base64.b64encode(buf.getvalue()).decode('utf-8')

        # Return the processed image and GPU information as JSON
        return jsonify({
            'image': img_base64,
            'gpu': torch.cuda.is_available(),
            'device': device_used
        })

    except RuntimeError as e:
        # Handle runtime errors, such as GPU out of memory (OOM) errors
        print(f"Runtime error: {e}")
        return jsonify({'error': str(e)}), 500

    finally:
        # Ensure GPU memory is cleared after task completion, whether successful or not
        if torch.cuda.is_available():
            torch.cuda.empty_cache()  # Clear the GPU cache
            print("GPU cache cleared.")


if __name__ == '__main__':
    # Start the Flask app on port 5000
    app.run(host='0.0.0.0', port=5000)
