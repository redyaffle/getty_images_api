getty_images_api
================

Query Getty Images API for Images

This is a small ruby script that opens a csv, pushes the first 
column of the csv into an array, and then queries Getty Image's API
for each of the search terms. It then takes those query results 
and downloads up to 50 images (depending on results) from 
Getty, placing them in nested directories based on their original
source.

## To run the script:

`ruby get_images.rb my_csv1.csv my_csv2.csv`

## Setup

You'll need to modify line 42 of get_images.rb to include your
client_key and client_secret. Register to receive each of these 
at [api.gettyimages.com](http://api.gettyimages.com/). Also, set
max images to download on line 7 to a desired number. 

I've included a sample CSV you can use to test. It will download
images to your current directory. To run the test.csv, run the 
following: 

`ruby get_images.rb test_celebrities.csv`



