import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

class RegisterForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const RegisterForm({super.key, required this.formKey, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginRegisterController>(
      builder: (loginRegisterController) {
        return Form(
          key: formKey,
          child: Padding(
            padding: EdgeInsets.all(responsivePadding(context)),
            child: Column(
              children: [
                AppTextFormField(
                  controller: loginRegisterController.registerNameController,
                  labelText: 'Full Name',
                  type: AppTextFormFieldType.text,
                  validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                ),

                const SizedBox(height: 16),
                AppTextFormField(
                  controller: loginRegisterController.registerMemberCodeController,
                  labelText: 'Member Code',
                  type: AppTextFormFieldType.text,
                  helperText: 'Enter the member code provided by your organization',
                  validator: (value) => value == null || value.isEmpty ? 'Please enter MemberCode' : null,
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  controller: loginRegisterController.registerEmailController,
                  labelText: 'UserId',
                  type: AppTextFormFieldType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your userId';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  controller: loginRegisterController.registerPasswordController,
                  labelText: 'Password',
                  type: AppTextFormFieldType.password,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loginRegisterController.isLoading.value ? null : onSubmit,
                    child:
                        loginRegisterController.isLoading.value
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                            : const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
