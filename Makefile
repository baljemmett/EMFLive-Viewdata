image:
	docker build . -t verity.microwavepizza.co.uk/emflive:latest
	make -C ./reminder-calls image

push:
	docker push verity.microwavepizza.co.uk/emflive:latest
	make -C ./reminder-calls push
