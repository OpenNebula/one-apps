const API_URL = "/chat";

async function sendMessage() {
    let inputField = document.getElementById("message-input");
    let message = inputField.value.trim();
    if (!message) return;

    let messageTimestamp = Date.now();
    addMessage(message, "user-message", messageTimestamp);

    inputField.value = "";

    // Add the "waiting for response" message with moving dots
    let waitingMessage = addMessage("Waiting for an answer", "waiting-message", Date.now(), true);

    try {
        let responseText;

        let response = await fetch(API_URL, {
            method: "POST",
            headers: {
                "Accept": "*/*",
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ message: message })
        });

        if (!response.ok) {
            throw new Error("Network response was not ok");
        }

        let data = await response.json();
        responseText = data.response;

        // Remove the "waiting for response" message and add the real bot response
        waitingMessage.remove();
        let botMessageTimestamp = Date.now();
        addMessage(responseText, "bot-message", botMessageTimestamp);


    } catch (error) {
        console.error("Error fetching response:", error);
        waitingMessage.remove(); // Remove the waiting message
        addMessage("Error getting response", "bot-message", Date.now());
    }
}

function addMessage(text, className, timestamp, isWaiting = false) {
    let chatHistory = document.getElementById("chat-history");
    let newMessage = document.createElement("div");

    if (isWaiting) {
        newMessage.classList.add("message", "waiting-message");
        newMessage.innerHTML = `<span>${text}</span><span class="loading-circle"></span>`; // Add the loading circle
    } else {

        const markdownText = marked.parse(text)
        newMessage.innerHTML = markdownText

        newMessage.classList.add("message", className);
    }

    // If not a waiting message, add timestamp
    if (!isWaiting) {
        let timestampElem = document.createElement("div");
        timestampElem.classList.add("timestamp");
        timestampElem.dataset.timestamp = timestamp;
        timestampElem.textContent = calculateElapsedTime(timestamp);

        newMessage.appendChild(timestampElem);
    }

    chatHistory.appendChild(newMessage);

    setInterval(() => updateTimestamp(newMessage.querySelector(".timestamp")), 1000);

    chatHistory.scrollTop = chatHistory.scrollHeight;

    return newMessage; // return the message element so we can remove it later
}


// Function to calculate elapsed time for the timestamp
function calculateElapsedTime(timestamp) {
    let now = Date.now();
    let elapsed = (now - timestamp) / 1000;

    if (elapsed < 60) {
        return `${Math.floor(elapsed)} seconds ago`;
    } else {
        let minutes = Math.floor(elapsed / 60);
        return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    }
}

// Function to update the timestamp periodically
function updateTimestamp(timestampElem) {
    let timestamp = timestampElem?.dataset?.timestamp;
    if (timestampElem)
        timestampElem.textContent = calculateElapsedTime(parseInt(timestamp));
}

// Function to handle 'Enter' key press to send the message
function handleKeyPress(event) {
    if (event.key === "Enter") {
        sendMessage();
    }
}
