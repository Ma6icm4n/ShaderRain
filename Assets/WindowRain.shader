Shader "Unlit/WindowRain"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size("Size", Float) = 1
        _T("Time", Float) = 1
        //used to operate on water drops
        _Distorsion("Distorsion", range(-5, 5)) = 1
        //used to Blur the background in the GrabImage
        _Blur("Blur", range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" } //very important for the rendering of the shader used to create the transparency
        LOD 100
            
        GrabPass{"_GrabTexture"} //used to take the texture that is behind our glass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #define S(a, b, t) smoothstep(a, b, t) //simplification for the code
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 grabUv : TEXCOORD1;// we add the uv coordinate of our grabTexture
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex, _GrabTexture;
            float4 _MainTex_ST;
            float _Size, _T, _Distorsion, _Blur;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.grabUv = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex)); //here we compute the grabTexture with ou UV coordinate
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            //this function is just used to create randomization
            float N21(float2 p) {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            float3 Layer(float2 UV, float t)
            {
                //aspect ratio for the box in our shader
                float2 aspect = float2 (2, 1);
                //uv coordinates that we tweak with the size and aspect ratio
                float2 uv = UV * _Size * aspect;
                //modification of coordinate with the time
                uv.y += t * .25;

                float2 gv = frac(uv) - 0.5;
                //create id for every box in our shader
                float2 id = floor(uv);
                //randomize ID
                float n = N21(id);
                t += n * 6.2831;

                float w = UV.y * 10;
                //modification of the x coordinate to create wiggle and that water drops are not crossing boxes end cut themself 
                float x = (n - .5) * .8; //-.4 to .4
                x += (.4 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * .45;
                //function to modification of the speed of the y coordinates movement, also used to not cut the drops in the bottom box
                float y = -sin(t + sin(t + sin(t) * 0.5)) * .45;
                y -= (gv.x - x) * (gv.x - x);
                //change the drop Position of the drops in the box and the from to create drops that are more realistics
                float2 dropPos = (gv - float2(x, y)) / aspect;
                float drop = S(.05, .03, length(dropPos));
                //trails that follow drops
                float2 trailPos = (gv - float2(x, t * .25)) / aspect;
                trailPos.y = (frac(trailPos.y * 8) - .5) / 8;
                float trail = S(.03, .01, length(trailPos));
                //fog eraser that follow the drops Trail Position
                float fogTrail = S(-.05, .05, dropPos.y);
                fogTrail *= S(.5, y, gv.y);
                trail *= fogTrail;
                fogTrail *= S(.05, .04, abs(dropPos.x));

                //final offset
                float2 offset = drop * dropPos + trail * trailPos;

                return float3(offset, fogTrail);

            }

            fixed4 frag(v2f i) : SV_Target
            {
                //provide t time and reset time at 2 hours to forbid random pattern to appear
                float t = fmod(_Time.y + _T, 7200);
                
                float4 col = 0;
                //create layers to add multiplke different pattern to the drops on the windows with multiple grid;
                float3 drops = Layer(i.uv, t);
                drops += Layer(i.uv*1.23+7.68, t);
                drops += Layer(i.uv*1.27+2.6, t);
                drops += Layer(i.uv * 4.56 + 3.89, t);
                drops += Layer(i.uv * 8.23 - 3.26, t);
                //used to cancel the distorsion with the camera distance
                float fade = 1 - saturate(fwidth(i.uv) * 50);
                //create the Blur effect and cancel it with the camera distance
                float blur = _Blur * 7 * (1 - drops.z* fade);

                //create projectionUv
                float2 projUv = i.grabUv.xy / i.grabUv.w;
                //add the distance effect to the shader and the projectionUv
                projUv += drops.xy * _Distorsion * fade;
                //attenuate blur effect
                blur *= .01;
                //this for is used to create blur randomisation and smoothness arround every uv coordinate
                const float numSamples = 32;
                //angle to determines the point to blur
                float a = N21(i.uv)*6.2831;
                for (float i = 0; i < numSamples; i++)
                {
                    //offset the point to blur rotating around it
                    float2 offset = float2(sin(a), cos(a)) * blur;
                    //adding range and randomization of the point during the rotation
                    offset *= frac(sin((i + 1) * 496.) * 4568.);
                    //apply it on the texture grabbed
                    col += tex2D(_GrabTexture, projUv+offset);
                    a++;
                }
                //average of the randomisation
                col /= numSamples;
                return col*.9;
            }
            ENDCG
        }
    }
}
