# Mojo Introduction
Mojo is a super-charged language that delivers C-like performance with the user-friendliness of Python. It's designed to bridge the gap between research and production, empowering you to write lightning-fast code without sacrificing readability or ease of use. Think of it as Python on steroids, ready to tackle computationally intensive tasks with ease. Mojo is a young but ambitious programming language making waves in the AI world. Mojo aims to address a key pain point: unlocking AI hardware's full potential without sacrificing developer experience. Currently in a preview release, Mojo has already garnered interest from both academia and industry. While not yet open-source, the creators plan to make it so in the future
# JPEG Decoder Overview
A JPEG decoder is a crucial component that interprets and decodes JPEG image files, facilitating their display or manipulation. It processes the encoded data, performing tasks such as entropy decoding, color space conversion, and dequantization to reconstruct the image.
# Implementation in Three Languages
I implemented the JPEG decoder in three programming languages: C, Python, and Mojo. The initial implementation, already available to me, was in C and served as the baseline:<br>
https://github.com/kittennbfive/kittenJPEG/tree/main <br> 
While I optimized the C implementation by removing unnecessary computations, the Python and Mojo versions were developed from scratch. I translated the new C code into both Python and Mojo, enabling a comprehensive comparison of their performance and efficiency. For each implementation, three images of different sizes were considered to measure the performance: (480, 680, 3), (848, 875, 3), and (2827, 2920, 3) where these dimensions represent the RGB pixel sizes of the images under consideration
# Specifications
All of the three codes will work only for Baseline JPEG with Huffman-Encoding, 8 bit precision and YCbCr-data. EXIF-data will be skipped without being decoded, just use something like ```exiftool```. This code does support Chroma-subsampling and dimensions that are not a multiple of 8 pixels. If you just want to view a jpg-file this is not what you are looking for at all, there are tons of image-viewers for all existing operating systems. However if you want to know more about the internals of JPEG, write or debug your own decoder this code could be handy. The main purpose of this is to see the performance difference when the same algorithm is implemented between 3 different languages.
# Language Comparison
In the performance evaluation, C demonstrated the highest execution speed, followed by Mojo, which exhibited approximately 1.5 times lower performance than C. Python, being an interpreted language, showed the slowest execution speed, lagging nearly 100 times behind C. The y-axis in the line graph is presented in logarithmic cycles in millions to enhance the visibility of differences between Mojo, C, and Python implementations. The line graph visualizes the performance across the three image sizes, providing a comprehensive comparison.
![alt text](https://github.com/taalhaataahir0102/Jpeg-Decoder/blob/main/graph/graph.png)

The following table shows the total cycles taken by the Jpeg decoder algorithm (excluding the cycles taken for file reading and writing) for each language:

![alt text](https://github.com/taalhaataahir0102/Jpeg-Decoder/blob/main/graph/table.png)

These cycles were measured through perf profiling tool
