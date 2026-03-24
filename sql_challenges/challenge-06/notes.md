# Notes

1. To raise an error we use RAISE_APPLICATION_ERROR, it takes a number and a message, the number should be a between 2000 and 2099 (Technically it doesnt matter which number you use, but there are some recommended numbers for certain scenarios)

2. OLD and NEW pseudo records used exclusively within row level triggers to access the data of the row being processed