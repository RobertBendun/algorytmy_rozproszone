#include <algorithm>
#include <charconv>
#include <chrono>
#include <cstring>
#include <iostream>
#include <string_view>
#include <thread>
#include <vector>

#include <SFML/Audio.hpp>
#include <SFML/Graphics.hpp>
#include <SFML/Network.hpp>

using namespace std::chrono_literals;

enum class Checkbox_State
{
	None,
	Sending,
	Receiving,
};

constexpr unsigned Checkbox_States_Count = 3;

bool left_mouse_button_pressed = false;

auto checkbox(sf::RenderWindow &window, Checkbox_State btn_state) -> bool
{

	auto const [x, y] = window.getSize();
	sf::CircleShape shape;

	auto const w = 2*x / 3, h = 2*y / 3;
	auto const s = (float)std::min(w, h);

	shape.setPosition(x/2 - (s / 2), y/2 - (s / 2));
	shape.setRadius(s / 2);
	shape.setPointCount(6);

	switch (btn_state) {
	case Checkbox_State::None: shape.setFillColor(sf::Color(0x81, 0xa1, 0xc1)); break;
	case Checkbox_State::Sending: shape.setFillColor(sf::Color(0xa3, 0xbe, 0x8c)); break;
	case Checkbox_State::Receiving: shape.setFillColor(sf::Color(0xbf, 0x61, 0x6a)); break;
	}

	window.draw(shape);

	static bool last_button_state = false;
	static bool enabled = true;
	if (left_mouse_button_pressed != last_button_state) {
		last_button_state = !last_button_state;
		if (last_button_state) {
			enabled = !enabled;
		}
	}

	return enabled;
}

struct Graphics
{
	Graphics()
		: window(sf::VideoMode(800, 600), "Audio chat")
		, last_frame_time(std::chrono::system_clock::now())
	{
	}

	void begin()
	{
		for (sf::Event event; window.pollEvent(event); ) {
			switch (event.type) {
			case sf::Event::Closed:
				window.close();
				break;

			case sf::Event::KeyPressed:
				if (event.key.code == sf::Keyboard::Key::Q)
					window.close();
				break;

			case sf::Event::MouseButtonPressed:
				 if (event.mouseButton.button == sf::Mouse::Button::Left) left_mouse_button_pressed = true; break;
			case sf::Event::MouseButtonReleased:
				if (event.mouseButton.button == sf::Mouse::Button::Left) left_mouse_button_pressed = false; break;
			default:;
			}
		}

		window.clear(sf::Color(0x5e, 0x81, 0xac));
	}

	void end()
	{
		window.display();
		auto current_time = std::chrono::system_clock::now();
		if ((current_time - last_frame_time) < 10ms)
			std::this_thread::sleep_for(10ms - (current_time - last_frame_time));
		last_frame_time = current_time;
	}

	sf::RenderWindow window;
	std::chrono::time_point<std::chrono::system_clock> last_frame_time;
	bool ready;
	bool recording;
};

struct User
{
	sf::IpAddress ip;
	unsigned portNumber;
};

struct Networking
{
	static inline unsigned myPort = 0;

	void listen(std::stop_token stop)
	{
		listener.setBlocking(false);

		while (!stop.stop_requested()) {
			for (sf::Tcp_Socket client; listener.accept(client) == sf::Socket::Done; ) {
				/* TODO: continue from this */
			}
		}

		listener.close();
	}

	Networking()
		: thread([this](std::stop_token stop) { listen(std::move(stop)); })
	{
		for (std::string line; std::getline(std::cin, line); ) {
			User user;

			auto s = std::string_view(line);
			auto begin = s.find_first_not_of(" \n\t\r");
			auto end = s.find_last_not_of(" \n\t\r");
			s = s.substr(end - begin);

			if (s[0] == ':' || s.starts_with("localhost")) {
			user.ip = sf::IpAddress::LocalHost;
				s.remove_prefix(s.find(':') + 1);
			}

			std::from_chars(std::cbegin(s), std::cend(s), user.portNumber);
			users.push_back(std::move(user));
		}
	}

	std::jthread thread;
	std::vector<User> users;
	sf::TcpListener listener;
};

struct Program
	: Graphics
	, Networking
{
	void draw()
	{
		if (checkbox(window, ready
					? (recording
						? Checkbox_State::Sending
						: Checkbox_State::Receiving)
					: Checkbox_State::None)) {
			recording = true;
		} else {
			recording = false;
		}
	}

	void loop()
	{
		while (window.isOpen()) {
			Graphics::begin();
			draw();
			Graphics::end();
		}
	}
};


auto main(int argc, char **argv) -> int
{
	if (argc != 2) {
		std::cerr << "wrong number of arguments\n";
		return 1;
	}

	char const* port = argv[1];
	std::from_chars(port, port + std::strlen(port), Networking::myPort);

	Program{}.loop();
}
