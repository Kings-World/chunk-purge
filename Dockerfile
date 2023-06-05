FROM eclipse-temurin:17-jdk

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  unzip zip python3 python3-pip jq

RUN wget https://github.com/Querz/mcaselector/releases/download/2.1/mcaselector-2.1.jar
RUN wget https://download2.gluonhq.com/openjfx/17.0.7/openjfx-17.0.7_linux-x64_bin-sdk.zip
RUN wget https://download2.gluonhq.com/openjfx/17.0.7/openjfx-17.0.7_linux-x64_bin-jmods.zip
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip

COPY mc-nbt-edit/* ./

RUN pip3 install -r requirements.txt

RUN unzip openjfx-17.0.7_linux-x64_bin-sdk.zip
RUN unzip openjfx-17.0.7_linux-x64_bin-jmods.zip
RUN unzip awscliv2.zip
RUN rm *.zip

RUN ./aws/install

ENV PATH_TO_FX=/app/javafx-sdk-17.0.7/lib
ENV PATH_TO_FX_MODS=/app/javafx-jmods-17.0.7

RUN $JAVA_HOME/bin/jlink --module-path $PATH_TO_FX_MODS \
    --add-modules java.se,javafx.fxml,javafx.web,javafx.media,javafx.swing \
    --bind-services --output /app/jdkfx-20.jdk

ENV JAVA_HOME=/app/jdkfx-20.jdk

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV PATH="$JAVA_HOME/bin:$PATH"

COPY ./entrypoint.sh /

CMD ["/bin/sh", "/entrypoint.sh"]