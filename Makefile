# Makefile para controlar la app de DMARCDefense Spoofing Tool

APP_NAME=dmarcdefensespoofingtool-dmarcdefense-app-1
TEMPLATES_DIR=templates
REQUIRED_TEMPLATES=form.html success.html error.html

check-templates:
	@echo "🔍 Verificando templates..."
	@for template in $(REQUIRED_TEMPLATES); do \
		if [ ! -f "$(TEMPLATES_DIR)/$$template" ]; then \
			echo "❌ Falta el template: $(TEMPLATES_DIR)/$$template"; \
			exit 1; \
		fi \
	done
	@echo "✅ Todos los templates están presentes."

up: check-templates
	docker-compose up --build -d
	@echo "Esperando a que la aplicación esté lista..."
	@sleep 5
	docker exec -it $(APP_NAME) python create_admin.py
down:
	docker-compose down

rebuild:
	docker-compose down
	docker-compose build
	docker-compose up -d
	@echo "Esperando a que la aplicación esté lista..."
	@sleep 5
	docker exec -it $(APP_NAME) python create_admin.py

logs:
	docker logs -f $(APP_NAME)

status:
	docker ps --filter "name=$(APP_NAME)"

health:
	docker inspect --format='{{.State.Health.Status}}' $(APP_NAME)

restart:
	docker-compose restart

shell:
	docker exec -it $(APP_NAME) /bin/bash
