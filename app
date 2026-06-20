from flask import Flask, request, jsonify, send_from_directory
import os
import uuid
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
ALLOWED_EXTENSIONS = {
    'png', 'jpg', 'jpeg', 'jfif', 'jfi', 'jif',
    'gif', 'webp', 'svg', 'bmp', 'ico', 'tif', 'tiff',
    'avif', 'apng', 'flif', 'heic', 'heif', 'raw',
    'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf',
    'psd', 'ai', 'eps', 'pdf'
}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 200 * 1024 * 1024

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/')
def index():
    return send_from_directory('public', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('public', path)

@app.route('/upload', methods=['POST'])
def upload_images():
    if 'images' not in request.files:
        return jsonify({'error': 'No image files provided'}), 400
    
    files = request.files.getlist('images')
    
    if not files or all(f.filename == '' for f in files):
        return jsonify({'error': 'No images selected'}), 400
    
    if len(files) > 20:
        return jsonify({'error': 'Maximum 20 images allowed'}), 400
    
    uploaded = []
    errors = []
    base_url = request.host_url.rstrip('/')
    
    for file in files:
        if file.filename == '':
            continue
        
        if file and allowed_file(file.filename):
            ext = file.filename.rsplit('.', 1)[1].lower()
            filename = f"{uuid.uuid4().hex}.{ext}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            
            image_url = f"{base_url}/uploads/{filename}"
            uploaded.append({
                'url': image_url,
                'filename': filename,
                'originalName': secure_filename(file.filename),
                'size': os.path.getsize(filepath)
            })
        else:
            errors.append(f"Invalid file type: {file.filename}")
    
    if uploaded:
        return jsonify({
            'success': True,
            'uploaded': uploaded,
            'count': len(uploaded),
            'errors': errors if errors else None
        })
    
    return jsonify({'error': 'No valid images found', 'errors': errors}), 400

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/images')
def list_images():
    images = []
    for filename in os.listdir(app.config['UPLOAD_FOLDER']):
        if allowed_file(filename):
            images.append({
                'filename': filename,
                'url': f"{request.host_url.rstrip('/')}/uploads/{filename}"
            })
    images.reverse()
    return jsonify({'images': images[:50]})

@app.route('/images/<filename>', methods=['DELETE'])
def delete_image(filename):
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(filepath):
        os.remove(filepath)
        return jsonify({'success': True, 'message': 'Image deleted'})
    return jsonify({'error': 'Image not found'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
