package com.freerdp.freerdpcore.presentation;

import android.app.Dialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.Window;
import android.widget.Button;
import android.widget.TextView;

import com.freerdp.freerdpcore.R;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

public class AgreementsConsentDialog extends Dialog
{
	private static final String PREFS_NAME = "freerdp_store";
	private static final String KEY_AGREEMENTS_ACCEPTED = "launch_agreements_accepted_v1";
	private static final String ASSET_PRIVACY_POLICY = "bihu-privacy-policy.md";
	private static final String ASSET_USER_AGREEMENT = "bihu-user-agreement.md";

	private final Runnable onAgree;
	private final Runnable onExit;

	public AgreementsConsentDialog(Context context, Runnable onAgree, Runnable onExit)
	{
		super(context, R.style.Theme_Main);
		this.onAgree = onAgree;
		this.onExit = onExit;
	}

	@Override protected void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setContentView(R.layout.dialog_agreements_consent);
		setCancelable(false);
		setCanceledOnTouchOutside(false);

		TextView privacyText = findViewById(R.id.agreement_privacy_text);
		TextView userText = findViewById(R.id.agreement_user_text);
		Button btnExit = findViewById(R.id.btn_exit_app);
		Button btnAgree = findViewById(R.id.btn_agree_continue);

		String privacyContent = loadAssetText(ASSET_PRIVACY_POLICY);
		String userContent = loadAssetText(ASSET_USER_AGREEMENT);

		privacyText.setText(stripMarkdownFormatting(privacyContent));
		userText.setText(stripMarkdownFormatting(userContent));

		btnExit.setOnClickListener(v -> {
			if (onExit != null)
				onExit.run();
		});

		btnAgree.setOnClickListener(v -> {
			setLaunchAgreementsAccepted(getContext(), true);
			if (onAgree != null)
				onAgree.run();
			dismiss();
		});

		Window window = getWindow();
		if (window != null)
		{
			window.setLayout(
				(int)(getContext().getResources().getDisplayMetrics().widthPixels * 0.92),
				(int)(getContext().getResources().getDisplayMetrics().heightPixels * 0.88)
			);
		}
	}

	private String loadAssetText(String assetName)
	{
		try (InputStream is = getContext().getAssets().open(assetName);
		     BufferedReader reader = new BufferedReader(new InputStreamReader(is, "UTF-8")))
		{
			StringBuilder sb = new StringBuilder();
			String line;
			while ((line = reader.readLine()) != null)
			{
				sb.append(line).append("\n");
			}
			return sb.toString();
		}
		catch (IOException e)
		{
			return "";
		}
	}

	private String stripMarkdownFormatting(String markdown)
	{
		if (markdown == null || markdown.isEmpty())
			return "";

		String result = markdown;
		result = result.replaceAll("(?m)^#{1,6}\\s+", "");
		result = result.replaceAll("\\*\\*(.+?)\\*\\*", "$1");
		result = result.replaceAll("__(.+?)__", "$1");
		result = result.replaceAll("`(.+?)`", "$1");
		result = result.replaceAll("\\[(.+?)\\]\\(.+?\\)", "$1");
		result = result.replaceAll("(?m)^>\\s+", "");
		result = result.replaceAll("(?m)^-\\s+", "• ");
		result = result.replaceAll("(?m)^\\s*$\n", "\n");
		result = result.replaceAll("\n{3,}", "\n\n");

		return result.trim();
	}

	public static boolean hasAcceptedLaunchAgreements(Context context)
	{
		SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
		return prefs.getBoolean(KEY_AGREEMENTS_ACCEPTED, false);
	}

	public static void setLaunchAgreementsAccepted(Context context, boolean accepted)
	{
		SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
		prefs.edit().putBoolean(KEY_AGREEMENTS_ACCEPTED, accepted).apply();
	}
}
