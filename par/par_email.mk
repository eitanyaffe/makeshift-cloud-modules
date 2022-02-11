send_email:
	python3 $(MAKESHIFT_ROOT)/makeshift-core/send_email.py \
		-k $(SENDGRID_API_KEY) \
		-f $(PAR_NOTIFY_FROM_EMAIL) \
		-t $(PAR_NOTIFY_TO_EMAIL) \
		-s "$(PAR_NOTIFY_SUBJECT)" \
		-m "$(PAR_NOTIFY_MESSAGE)"
