gl.setup(NATIVE_WIDTH/2, NATIVE_HEIGHT/2)

util.no_globals()

-- Public domain adapted from https://github.com/libretro/glsl-shaders/blob/master/film/shaders/film_noise.glsl
local retro = resource.create_shader[[
    #define x_off_r 0.08
    #define y_off_r 0.05
    #define x_off_g -0.08
    #define y_off_g -0.05
    #define x_off_b -0.08
    #define y_off_b 0.045
    #define grain_str 12.0
    #define hotspot 2.2
    #define vignette 0.3
    #define noise_toggle 1.0

    uniform samplerExternalOES Texture;
    uniform sampler2D noise;

    uniform float FrameCount;
    varying vec2 TexCoord;
    uniform vec4 Color;

    //https://www.shadertoy.com/view/4sXSWs strength= 16.0
    float filmGrain(vec2 uv, float strength, float timer ){
        float x = (uv.x + 4.0 ) * (uv.y + 4.0 ) * ((mod(timer, 800.0) + 10.0) * 10.0);
        return  (mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01)-0.005) * strength;
    }

    float hash(float n) {
        return fract(sin(n)*43758.5453123);
    }

    void main() {
        vec2 middle = TexCoord.xy - 0.5;
        float len = length(middle);
        float vig = smoothstep(0.0, 0.5, len);

        // create the noise effects from a LUT of actual film noise
        vec4 film_noise1 = texture2D(noise, TexCoord.xx * 2.0 *
            sin(hash(mod(FrameCount, 47.0))));
        vec4 film_noise2 = texture2D(noise, TexCoord.xy * 2.0 *
            cos(hash(mod(FrameCount, 92.0))));

        vec2 red_coord = TexCoord + 0.01 * vec2(x_off_r, y_off_r);
        vec3 red_light = texture2D(Texture, red_coord).rgb;
        vec2 green_coord = TexCoord + 0.01 * vec2(x_off_g, y_off_g);
        vec3 green_light = texture2D(Texture, green_coord).rgb;
        vec2 blue_coord = TexCoord + 0.01 * vec2(x_off_r, y_off_r);
        vec3 blue_light = texture2D(Texture, blue_coord).rgb;

        vec3 film = vec3(red_light.r, green_light.g, blue_light.b);
        film += filmGrain(TexCoord.xy, grain_str, FrameCount);

        film *= (vignette > 0.5) ? (1.0 - vig) : 1.0; // Vignette
        film += ((1.0 - vig) * 0.2) * hotspot; // Hotspot

        // Apply noise effects (or not)
        if (hash(FrameCount) > 0.99 && noise_toggle > 0.5)
            gl_FragColor = vec4(mix(film, film_noise1.rgb, film_noise1.a), 1.0);
        else if (hash(FrameCount) < 0.01 && noise_toggle > 0.5)
            gl_FragColor = vec4(mix(film, film_noise2.rgb, film_noise2.a), 1.0);
        else
            gl_FragColor = vec4(film, 1.0);
    }
]]

local noise = resource.load_image "noise.png"

local video

util.json_watch("config.json", function(config)
    if video then
        video:dispose()
    end
    video = resource.load_video{ -- this fails for image..
        file = config.file.asset_name,
        looped = true
    }
end)

local frame_count = 0

function node.render()
    frame_count = frame_count + 1
    retro:use{
        noise = noise,
        FrameCount = frame_count,
    }
    video:draw(0, 0, WIDTH, HEIGHT)
end
