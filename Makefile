
TARGET = prime_checker
SRC = ConsoleApplication6.cpp
CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -pthread -I. -I/usr/local/include
LDFLAGS = -L/usr/local/lib -lprometheus-cpp-core -lprometheus-cpp-pull

PKG_NAME = prime-checker
DEB_FILE = $(PKG_NAME).deb

.PHONY: all
all: build

.PHONY: setup
setup:
	@echo "📦 Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y \
		build-essential \
		g++ \
		make \
		wget \
		git \
		cmake \
		libcurl4-openssl-dev \
		zlib1g-dev
	@echo "✔ dependencies ready"

.PHONY: deps
deps:
	@echo "📦 Downloading httplib.h..."
	mkdir -p third_party
	wget -q -O third_party/httplib.h \
		https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h
	@echo "✔ httplib ready"

.PHONY: prom
prom:
	@echo "📦 Building prometheus-cpp..."
	if [ ! -f /usr/local/lib/libprometheus-cpp-core.so ]; then \
		git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
		cd /tmp/prom && mkdir build && cd build && \
		cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
		make -j$$(nproc) && sudo make install && sudo ldconfig ; \
	else \
		echo "✔ prometheus already installed"; \
	fi

.PHONY: build
build: setup deps prom
	@echo "🚀 Building application..."
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)
	@echo "✔ build complete"

.PHONY: run
run:
	./$(TARGET)

.PHONY: test
test: build
	@echo "🧪 Testing API..."
	./$(TARGET) &
	sleep 2
	curl "http://localhost:8080/check?num=17" || true

.PHONY: clean
clean:
	rm -f $(TARGET)
	rm -rf third_party

.PHONY: docker-build
docker-build:
	docker build -t $(PKG_NAME):latest .

.PHONY: docker-run
docker-run:
	docker run -p 8080:8080 -p 9090:9090 $(PKG_NAME):latest

.PHONY: deploy
deploy:
	@echo "🚀 Deploying with Helm..."
	docker pull your-dockerhub/$(PKG_NAME):latest
	helm upgrade --install $(PKG_NAME) ./prime-checker \
		--set image.repository=your-dockerhub/$(PKG_NAME) \
		--set image.tag=latest

.PHONY: status
status:
	kubectl get pods
	kubectl get svc

.PHONY: port-forward
port-forward:
	kubectl port-forward svc/$(PKG_NAME) 8080:80

.PHONY: all-up
all-up: build docker-build deploy status
	@echo "🎉 SYSTEM READY"

.PHONY: package
package:
	@echo "--- Creating .deb package ---"

	mkdir -p prime-checker/DEBIAN
	mkdir -p prime-checker/usr/bin

	cp prime_checker prime-checker/usr/bin/

	echo "Package: prime-checker" > prime-checker/DEBIAN/control
	echo "Version: 1.0" >> prime-checker/DEBIAN/control
	echo "Architecture: amd64" >> prime-checker/DEBIAN/control
	echo "Maintainer: CI Builder <ci@example.com>" >> prime-checker/DEBIAN/control
	echo "Description: Prime number checker with Prometheus metrics" >> prime-checker/DEBIAN/control

	dpkg-deb --build prime-checker

	mv prime-checker.deb prime-checker.deb || true

	rm -rf prime-checker