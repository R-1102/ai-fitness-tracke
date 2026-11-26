import mediapipe as mp
import numpy as np
import cv2
import os
from tensorflow.keras.utils import to_categorical
from keras.layers import Input, Dense
from keras.models import Model
from sklearn.model_selection import train_test_split
from keras.callbacks import EarlyStopping
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import confusion_matrix

Up_folder = "/content/drive/MyDrive/Hammer  biceps counter model/data/HUP"
Down_folder = "/content/drive/MyDrive/Hammer  biceps counter model/data/HDown"

mp_drawing = mp.solutions.drawing_utils
mp_pose = mp.solutions.pose

def Extract_Lnd(path):
    data_size = 0
    landmarks = []

    for filename in os.listdir(path):
      with mp_pose.Pose(min_detection_confidence=0.5, min_tracking_confidence=0.5) as pose:

        image_path = os.path.join(path, filename)
        image = cv2.imread(image_path)

        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        image.flags.writeable = False

        results = pose.process(image)

        image.flags.writeable = True
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

        image = cv2.resize(image, (224, 224))

        if results.pose_landmarks:
            lst = []
            for i in results.pose_landmarks.landmark:
                lst.append(i.x - results.pose_landmarks.landmark[0].x)
                lst.append(i.y - results.pose_landmarks.landmark[0].y)

            landmarks.append(lst)
            data_size += 1
            mp_drawing.draw_landmarks(image, results.pose_landmarks, mp_pose.POSE_CONNECTIONS)
        else:
            cv2.putText(image, "No human detected", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

        cv2.putText(image, str(data_size), (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        cv2_imshow(image)

        if cv2.waitKey(1) == 27 or data_size>100:
            cv2.destroyAllWindows()
            break

    return np.array(landmarks)

Up_landmarks = Extract_Lnd(Up_folder)
np.save("Up.npy", Up_landmarks)


Down_landmarks = Extract_Lnd(Down_folder)
np.save("Down.npy", Down_landmarks)

# Load data
inftr = np.concatenate((Up_landmarks, Down_landmarks))
targ_lb = np.concatenate((np.zeros(len(Up_landmarks)), np.ones(len(Down_landmarks))))

# Convert labels to one-hot encoded 
targ_lb = to_categorical(targ_lb)

# Split the data into training and testing sets
x_train, x_test, y_train, y_test = train_test_split(inftr, targ_lb, test_size=0.2, random_state=42)

ip = Input(shape=(inftr.shape[1]))
m = Dense(128, activation="tanh")(ip)
m = Dense(64, activation="tanh")(m)
m = Dense(32, activation="tanh")(m)
m = Dense(16, activation="tanh")(m)
op = Dense(targ_lb.shape[1], activation="softmax")(m)

model = Model(inputs=ip, outputs=op)
model.compile(optimizer='rmsprop', loss="categorical_crossentropy", metrics=['acc'])
early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)

model.fit(x_train, y_train, epochs=80, validation_split=0.2, callbacks=[early_stopping])

# Save the model
model.save("HBC_CounterModel_UD_5Layer.h5")

# Evaluate the model 
loss, accuracy = model.evaluate(x_test, y_test)
print(f"Loss: {loss}")
print(f"Accuracy: {accuracy}")

# Predict classes for test set
predict_x = model.predict(x_test)
y_pred_class = np.argmax(predict_x, axis=1)
y_test_class = np.argmax(y_test, axis=1)

conf_matr = confusion_matrix(y_test_class, y_pred_class)

plt.figure(figsize=(8, 8))
sns.heatmap(conf_matr, annot=True, cmap="Blues", fmt='g')
plt.xlabel('Predicted labels')
plt.ylabel('Actual labels')
plt.show()